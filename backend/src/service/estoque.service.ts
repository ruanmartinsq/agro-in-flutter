import { prisma } from "../lib/prisma.js"
import { AppError } from "../errors/AppError.js"
import { CreateEstoqueBody, UpdateEstoqueBody } from "../types/estoque.types.js"

export class EstoqueError extends AppError {}

class EstoqueService {

    private assertPropriedadePertenceAoUsuario = async (propriedadeId: number, usuarioId: number) => {
        const propriedade = await prisma.propriedade.findFirst({
            where: { id: propriedadeId, usuario_id: usuarioId },
        })

        if (!propriedade) {
            throw new EstoqueError("Propriedade não encontrada.", 403)
        }
    }


    private findOwnedOrFail = async (id: number, usuarioId: number) => {
        const estoque = await prisma.estoque.findUnique({ where: { id } })

        if (!estoque) {
            throw new EstoqueError("Estoque não encontrado", 404)
        }

        const propriedade = await prisma.propriedade.findFirst({
            where: { id: estoque.propriedade_id, usuario_id: usuarioId },
        })

        if (!propriedade) {
            throw new EstoqueError("Acesso negado.", 403)
        }

        return estoque
    }

    create = async (usuarioId: number, data: CreateEstoqueBody) => {
        await this.assertPropriedadePertenceAoUsuario(data.propriedade_id, usuarioId)

        return prisma.estoque.create({ data })
    }

    findAll = async (usuarioId: number) => {
        const propriedades = await prisma.propriedade.findMany({
            where: { usuario_id: usuarioId },
            select: { id: true },
        })

        const ids = propriedades.map((p) => p.id)

        return prisma.estoque.findMany({
            where: { propriedade_id: { in: ids } },
        })
    }

    findById = async (usuarioId: number, id: number) => {
        return this.findOwnedOrFail(id, usuarioId)
    }

    update = async (usuarioId: number, id: number, data: UpdateEstoqueBody) => {
        await this.findOwnedOrFail(id, usuarioId)

        return prisma.estoque.update({
            where: { id },
            data,
        })
    }

    delete = async (usuarioId: number, id: number): Promise<void> => {
        await this.findOwnedOrFail(id, usuarioId)

        await prisma.estoque.delete({ where: { id } })
    }
}

export const estoqueService = new EstoqueService()