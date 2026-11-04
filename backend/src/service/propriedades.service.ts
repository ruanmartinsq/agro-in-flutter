import { prisma } from "../lib/prisma.js";
import { CreatePropertyBody, UpdatePropertyBody } from "../types/propriedades.types.js";
import { AppError } from "../errors/AppError.js";

// Erro de domínio simples
export class PropriedadeError extends AppError {}

class PropriedadesService {
    create = async (usuarioId: number, data: CreatePropertyBody) => {
        return prisma.propriedade.create({
            data: {
                ...data,
                usuario_id: usuarioId,
            },
        });
    };

    findAll = async (usuarioId: number) => {
        return prisma.propriedade.findMany({
            where: { usuario_id: usuarioId },
        });
    };

    findById = async (usuarioId: number, id: number) => {
        const propriedade = await prisma.propriedade.findFirst({
            where: { id, usuario_id: usuarioId },
        });

        if (!propriedade) {
            throw new PropriedadeError("Propriedade não encontrada.", 404);
        }

        return propriedade;
    };

    update = async (usuarioId: number, id: number, data: UpdatePropertyBody) => {
        await this.findById(usuarioId, id);

        return prisma.propriedade.update({
            where: { id },
            data,
        });
    };

    delete = async (usuarioId: number, id: number): Promise<void> => {
        await this.findById(usuarioId, id)

        await prisma.propriedade.delete({ where: { id } })
    };
}

export const propriedadesService = new PropriedadesService()