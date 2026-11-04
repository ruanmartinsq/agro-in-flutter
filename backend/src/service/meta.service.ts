import { prisma } from "../lib/prisma.js";
import { AppError } from "../errors/AppError.js";
import { CreateMetaBody, UpdateMetaBody } from "../types/meta.types.js";

export class MetaError extends AppError {}

class MetaService {

    private assertPropriedadePertenceAoUsuario = async (propriedadeId: number, usuarioId: number) => {
        const propriedade = await prisma.propriedade.findFirst({
            where: { id: propriedadeId, usuario_id: usuarioId },
        })

        if (!propriedade) {
            throw new MetaError("Propriedade não encontrada.", 403)
        }
    }

    private findOwnedOrFail = async (id: number, usuarioId: number) => {
        const meta = await prisma.meta.findUnique({ where: { id } })

        if (!meta) {
            throw new MetaError("Meta não encontrada", 404)
        }

        const propriedade = await prisma.propriedade.findFirst({
            where: { id: meta.propriedade_id, usuario_id: usuarioId },
        })

        if (!propriedade) {
            throw new MetaError("Acesso negado.", 403)
        }

        return meta
    }

    create = async (usuarioId: number, data: CreateMetaBody) => {
        await this.assertPropriedadePertenceAoUsuario(data.propriedade_id, usuarioId)

        return prisma.meta.create({
            data: {
                propriedade_id: data.propriedade_id,
                descricao: data.descricao,
                categoria: data.categoria ?? null,
                valor_alvo: data.valor_alvo ?? null,
                valor_atual: data.valor_atual ?? 0,
                unidade: data.unidade ?? null,
                responsavel: data.responsavel ?? null,
                prazo: new Date(data.prazo),
                status: data.status ?? "pendente",
            },
        })
    }

    findAll = async (usuarioId: number) => {
        const propriedades = await prisma.propriedade.findMany({
            where: { usuario_id: usuarioId },
            select: { id: true },
        })

        const ids = propriedades.map((p) => p.id);

        return prisma.meta.findMany({
            where: { propriedade_id: { in: ids } },
        })
    }

    findById = async (usuarioId: number, id: number) => {
        return this.findOwnedOrFail(id, usuarioId)
    }

    update = async (usuarioId: number, id: number, data: UpdateMetaBody) => {
        await this.findOwnedOrFail(id, usuarioId)

        const { prazo, ...resto } = data

        return prisma.meta.update({
            where: { id },
            data: {
                ...resto,
                ...(prazo ? { prazo: new Date(prazo) } : {}),
            },
        })
    }

    delete = async (usuarioId: number, id: number): Promise<void> => {
        await this.findOwnedOrFail(id, usuarioId)

        await prisma.meta.delete({ where: { id } })
    }
}

export const metaService = new MetaService()