import { prisma } from "../lib/prisma.js";
import type {
    AtualizarCasoFoliarBody,
    CriarCasoFoliarBody,
} from "../types/analise-foliar.types.js";
import {
    AnaliseFoliarError,
    camposPublicos,
} from "./analise-foliar.service.js";

const selecionarCaso = {
    id: true,
    titulo: true,
    cultura: true,
    tratamento: true,
    status: true,
    proxima_revisao_em: true,
    encerrado_em: true,
    criado_em: true,
    atualizado_em: true,
    propriedade: {
        select: {
            id: true,
            nome: true,
        },
    },
    analises: {
        orderBy: { criado_em: "asc" as const },
        select: camposPublicos,
    },
};

const dataValida = (valor?: string | null) => {
    if (!valor) return null;
    const data = new Date(valor);
    if (Number.isNaN(data.getTime())) {
        throw new AnaliseFoliarError("Data da próxima revisão inválida.", 400);
    }
    return data;
};

class CasoFoliarService {
    criar = async (usuarioId: number, entrada: CriarCasoFoliarBody) => {
        if (!Number.isInteger(entrada.analise_id) || entrada.analise_id <= 0) {
            throw new AnaliseFoliarError("Análise inválida.", 400);
        }

        const analise = await prisma.analiseFoliar.findFirst({
            where: { id: entrada.analise_id, usuario_id: usuarioId },
            select: {
                id: true,
                caso_id: true,
                ponto_vistoria_id: true,
                propriedade_id: true,
                cultura_informada: true,
                cultura_detectada: true,
            },
        });
        if (!analise) throw new AnaliseFoliarError("Análise não encontrada.", 404);
        if (analise.caso_id) {
            throw new AnaliseFoliarError("Esta análise já está em uma quarentena.", 409);
        }
        if (analise.ponto_vistoria_id) {
            throw new AnaliseFoliarError(
                "Análises de vistoria de área já são acompanhadas pelo próprio ponto.",
                409,
            );
        }

        const cultura = analise.cultura_informada ?? analise.cultura_detectada;
        const titulo =
            entrada.titulo?.trim().slice(0, 120) ||
            `${cultura || "Planta"} · acompanhamento`;
        const tratamento = entrada.tratamento?.trim().slice(0, 1000) || undefined;
        const padraoRevisao = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
        const proximaRevisao =
            entrada.proxima_revisao_em !== undefined
                ? dataValida(entrada.proxima_revisao_em)
                : padraoRevisao;

        return prisma.$transaction(async (tx) => {
            const caso = await tx.casoFoliar.create({
                data: {
                    usuario_id: usuarioId,
                    propriedade_id: analise.propriedade_id,
                    titulo,
                    ...(cultura ? { cultura } : {}),
                    ...(tratamento ? { tratamento } : {}),
                    proxima_revisao_em: proximaRevisao,
                },
                select: { id: true },
            });

            await tx.analiseFoliar.update({
                where: { id: analise.id },
                data: { caso_id: caso.id, etapa_acompanhamento: 0 },
            });

            return tx.casoFoliar.findUniqueOrThrow({
                where: { id: caso.id },
                select: selecionarCaso,
            });
        });
    };

    listar = async (usuarioId: number) =>
        prisma.casoFoliar.findMany({
            where: { usuario_id: usuarioId },
            orderBy: [{ status: "asc" }, { atualizado_em: "desc" }],
            select: selecionarCaso,
        });

    buscar = async (usuarioId: number, id: number) => {
        if (!Number.isInteger(id) || id <= 0) {
            throw new AnaliseFoliarError("Quarentena inválida.", 400);
        }
        const caso = await prisma.casoFoliar.findFirst({
            where: { id, usuario_id: usuarioId },
            select: selecionarCaso,
        });
        if (!caso) throw new AnaliseFoliarError("Quarentena não encontrada.", 404);
        return caso;
    };

    atualizar = async (
        usuarioId: number,
        id: number,
        entrada: AtualizarCasoFoliarBody,
    ) => {
        await this.buscar(usuarioId, id);
        const titulo = entrada.titulo?.trim().slice(0, 120);
        const tratamento = entrada.tratamento?.trim().slice(0, 1000);

        return prisma.casoFoliar.update({
            where: { id },
            data: {
                ...(titulo ? { titulo } : {}),
                ...(entrada.tratamento !== undefined
                    ? { tratamento: tratamento || null }
                    : {}),
                ...(entrada.proxima_revisao_em !== undefined
                    ? {
                          proxima_revisao_em: dataValida(
                              entrada.proxima_revisao_em,
                          ),
                      }
                    : {}),
            },
            select: selecionarCaso,
        });
    };

    encerrar = async (usuarioId: number, id: number) => {
        await this.buscar(usuarioId, id);
        return prisma.casoFoliar.update({
            where: { id },
            data: {
                status: "encerrado",
                encerrado_em: new Date(),
            },
            select: selecionarCaso,
        });
    };

    reabrir = async (usuarioId: number, id: number) => {
        await this.buscar(usuarioId, id);
        return prisma.casoFoliar.update({
            where: { id },
            data: {
                status: "em_quarentena",
                encerrado_em: null,
            },
            select: selecionarCaso,
        });
    };
}

export const casoFoliarService = new CasoFoliarService();
