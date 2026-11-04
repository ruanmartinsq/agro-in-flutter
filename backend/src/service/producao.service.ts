import { prisma } from "../lib/prisma.js"
import { AppError } from "../errors/AppError.js"
import { CreateProducaoBody, UpdateProducaoBody } from "../types/producao.types.js"

export class ProducaoError extends AppError {}

class ProducaoService {

    private assertPropriedadePertenceAoUsuario = async (propriedadeId: number, usuarioId: number) => {
        const propriedade = await prisma.propriedade.findFirst({
            where: { id: propriedadeId, usuario_id: usuarioId },
        })

        if (!propriedade) {
            throw new ProducaoError("Propriedade não encontrada.", 403)
        }
    }

    private findOwnedOrFail = async (id: number, usuarioId: number) => {
        const producao = await prisma.producao.findUnique({ where: { id } })

        if (!producao) {
            throw new ProducaoError("Produção não encontrada", 404)
        }

        const propriedade = await prisma.propriedade.findFirst({
            where: { id: producao.propriedade_id, usuario_id: usuarioId },
        });

        if (!propriedade) {
            throw new ProducaoError("Acesso negado.", 403)
        }

        return producao
    };

    create = async (usuarioId: number, data: CreateProducaoBody) => {
        await this.assertPropriedadePertenceAoUsuario(data.propriedade_id, usuarioId)

        return prisma.producao.create({
            data: {
                ...data,
                data_inicio: data.data_inicio ? new Date(data.data_inicio) : null,
                data_fim: data.data_fim ? new Date(data.data_fim) : null,
            },
        })
    }

    findAll = async (usuarioId: number) => {
        const propriedades = await prisma.propriedade.findMany({
            where: { usuario_id: usuarioId },
            select: { id: true },
        });

        const ids = propriedades.map((p) => p.id)

        return prisma.producao.findMany({
            where: { propriedade_id: { in: ids } },
        })
    }

    findById = async (usuarioId: number, id: number) => {
        return this.findOwnedOrFail(id, usuarioId)
    }

    update = async (usuarioId: number, id: number, data: UpdateProducaoBody) => {
        await this.findOwnedOrFail(id, usuarioId)

        const { data_inicio, data_fim, ...resto } = data

        return prisma.producao.update({
            where: { id },
            data: {
                ...resto,
                ...(data_inicio ? { data_inicio: new Date(data_inicio) } : {}),
                ...(data_fim ? { data_fim: new Date(data_fim) } : {}),
            },
        })
    }

    delete = async (usuarioId: number, id: number): Promise<void> => {
        await this.findOwnedOrFail(id, usuarioId)

        await prisma.producao.delete({ where: { id } })
    }
}

export const producaoService = new ProducaoService()