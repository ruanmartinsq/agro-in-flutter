import { prisma } from "../lib/prisma.js";
import type {
    AtualizarLocalizacaoPontoBody,
    CriarPontoVistoriaBody,
    CriarVistoriaAreaBody,
} from "../types/analise-foliar.types.js";
import {
    AnaliseFoliarError,
    camposPublicos,
} from "./analise-foliar.service.js";

const pontosPadrao = [
    { nome: "Frente do talhão", setor: "frente", ordem: 1 },
    { nome: "Lateral esquerda", setor: "esquerda", ordem: 2 },
    { nome: "Centro", setor: "centro", ordem: 3 },
    { nome: "Lateral direita", setor: "direita", ordem: 4 },
    { nome: "Fundo do talhão", setor: "fundo", ordem: 5 },
];

const selecionarVistoria = {
    id: true,
    nome: true,
    cultura: true,
    objetivo: true,
    status: true,
    concluido_em: true,
    criado_em: true,
    atualizado_em: true,
    propriedade: {
        select: {
            id: true,
            nome: true,
        },
    },
    pontos: {
        orderBy: { ordem: "asc" as const },
        select: {
            id: true,
            nome: true,
            setor: true,
            ordem: true,
            latitude: true,
            longitude: true,
            precisao_metros: true,
            analises: {
                orderBy: { criado_em: "asc" as const },
                select: camposPublicos,
            },
        },
    },
};

const resumo = <T extends { pontos: Array<{ analises: Array<{ status_geral: string }> }> }>(
    vistoria: T,
) => {
    const ultimas = vistoria.pontos
        .map((ponto) => ponto.analises.at(-1))
        .filter((analise): analise is { status_geral: string } => Boolean(analise));
    const pontosComSinal = ultimas.filter(
        (analise) =>
            !["aparentemente_saudavel", "inconclusivo"].includes(
                analise.status_geral,
            ),
    ).length;

    return {
        ...vistoria,
        resumo: {
            pontos_previstos: vistoria.pontos.length,
            pontos_fotografados: ultimas.length,
            cobertura:
                vistoria.pontos.length > 0
                    ? Math.round((ultimas.length / vistoria.pontos.length) * 100)
                    : 0,
            pontos_com_sinal: pontosComSinal,
            pontos_aparentemente_saudaveis: ultimas.filter(
                (analise) => analise.status_geral === "aparentemente_saudavel",
            ).length,
            pontos_inconclusivos: ultimas.filter(
                (analise) => analise.status_geral === "inconclusivo",
            ).length,
            nota:
                "Vistoria orientativa por pontos. A cobertura representa pontos registrados, não a porcentagem do talhão doente.",
        },
    };
};

class VistoriaAreaService {
    private validarPropriedade = async (usuarioId: number, propriedadeId?: number) => {
        if (propriedadeId === undefined) return;
        if (!Number.isInteger(propriedadeId) || propriedadeId <= 0) {
            throw new AnaliseFoliarError("Propriedade inválida.", 400);
        }
        const propriedade = await prisma.propriedade.findFirst({
            where: { id: propriedadeId, usuario_id: usuarioId },
            select: { id: true },
        });
        if (!propriedade) {
            throw new AnaliseFoliarError("Propriedade não encontrada.", 403);
        }
    };

    criar = async (usuarioId: number, entrada: CriarVistoriaAreaBody) => {
        const nome = entrada.nome?.trim().slice(0, 120);
        if (!nome) throw new AnaliseFoliarError("Informe o nome da vistoria.", 400);
        await this.validarPropriedade(usuarioId, entrada.propriedade_id);

        const vistoria = await prisma.vistoriaArea.create({
            data: {
                usuario_id: usuarioId,
                nome,
                ...(entrada.propriedade_id !== undefined
                    ? { propriedade_id: entrada.propriedade_id }
                    : {}),
                ...(entrada.cultura?.trim()
                    ? { cultura: entrada.cultura.trim().slice(0, 100) }
                    : {}),
                ...(entrada.objetivo?.trim()
                    ? { objetivo: entrada.objetivo.trim().slice(0, 500) }
                    : {}),
                pontos: { create: pontosPadrao },
            },
            select: selecionarVistoria,
        });
        return resumo(vistoria);
    };

    listar = async (usuarioId: number) => {
        const vistorias = await prisma.vistoriaArea.findMany({
            where: { usuario_id: usuarioId },
            orderBy: [{ status: "asc" }, { atualizado_em: "desc" }],
            select: selecionarVistoria,
        });
        return vistorias.map(resumo);
    };

    buscar = async (usuarioId: number, id: number) => {
        if (!Number.isInteger(id) || id <= 0) {
            throw new AnaliseFoliarError("Vistoria inválida.", 400);
        }
        const vistoria = await prisma.vistoriaArea.findFirst({
            where: { id, usuario_id: usuarioId },
            select: selecionarVistoria,
        });
        if (!vistoria) throw new AnaliseFoliarError("Vistoria não encontrada.", 404);
        return resumo(vistoria);
    };

    adicionarPonto = async (
        usuarioId: number,
        vistoriaId: number,
        entrada: CriarPontoVistoriaBody,
    ) => {
        const vistoria = await this.buscar(usuarioId, vistoriaId);
        if (vistoria.status !== "em_andamento") {
            throw new AnaliseFoliarError("Reabra a vistoria para adicionar pontos.", 409);
        }
        const nome = entrada.nome?.trim().slice(0, 100);
        if (!nome) throw new AnaliseFoliarError("Informe o nome do ponto.", 400);
        const maiorOrdem = Math.max(0, ...vistoria.pontos.map((ponto) => ponto.ordem));

        await prisma.pontoVistoria.create({
            data: {
                vistoria_id: vistoriaId,
                nome,
                setor: entrada.setor?.trim().slice(0, 60) || null,
                ordem: maiorOrdem + 1,
            },
        });
        return this.buscar(usuarioId, vistoriaId);
    };

    atualizarLocalizacao = async (
        usuarioId: number,
        vistoriaId: number,
        pontoId: number,
        entrada: AtualizarLocalizacaoPontoBody,
    ) => {
        const ponto = await prisma.pontoVistoria.findFirst({
            where: {
                id: pontoId,
                vistoria_id: vistoriaId,
                vistoria: { usuario_id: usuarioId },
            },
            select: { id: true },
        });
        if (!ponto) throw new AnaliseFoliarError("Ponto não encontrado.", 404);
        if (
            !Number.isFinite(entrada.latitude) ||
            entrada.latitude < -90 ||
            entrada.latitude > 90 ||
            !Number.isFinite(entrada.longitude) ||
            entrada.longitude < -180 ||
            entrada.longitude > 180
        ) {
            throw new AnaliseFoliarError("Coordenadas inválidas.", 400);
        }
        if (
            entrada.precisao_metros !== undefined &&
            (!Number.isFinite(entrada.precisao_metros) ||
                entrada.precisao_metros < 0)
        ) {
            throw new AnaliseFoliarError("Precisão do GPS inválida.", 400);
        }

        await prisma.pontoVistoria.update({
            where: { id: pontoId },
            data: {
                latitude: entrada.latitude,
                longitude: entrada.longitude,
                precisao_metros: entrada.precisao_metros ?? null,
            },
        });
        return this.buscar(usuarioId, vistoriaId);
    };

    concluir = async (usuarioId: number, id: number) => {
        await this.buscar(usuarioId, id);
        await prisma.vistoriaArea.update({
            where: { id },
            data: { status: "concluida", concluido_em: new Date() },
        });
        return this.buscar(usuarioId, id);
    };

    reabrir = async (usuarioId: number, id: number) => {
        await this.buscar(usuarioId, id);
        await prisma.vistoriaArea.update({
            where: { id },
            data: { status: "em_andamento", concluido_em: null },
        });
        return this.buscar(usuarioId, id);
    };
}

export const vistoriaAreaService = new VistoriaAreaService();
