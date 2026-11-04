import type { FastifyReply, FastifyRequest } from "fastify";

import {
    analiseFoliarService,
    AnaliseFoliarError,
} from "../service/analise-foliar.service.js";
import type {
    CriarAnaliseFoliarBody,
    FeedbackAnaliseFoliarBody,
} from "../types/analise-foliar.types.js";

const responderErro = (
    request: FastifyRequest,
    reply: FastifyReply,
    error: unknown,
    mensagem: string,
) => {
    if (error instanceof AnaliseFoliarError) {
        return reply.status(error.statusCode).send({ error: error.message });
    }

    request.log.error(error);
    return reply.status(500).send({ error: mensagem });
};

class AnaliseFoliarController {
    criar = async (
        request: FastifyRequest<{ Body: CriarAnaliseFoliarBody }>,
        reply: FastifyReply,
    ) => {
        try {
            const analise = await analiseFoliarService.criar(request.user.id, request.body);
            return reply.status(201).send(analise);
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao processar análise foliar.");
        }
    };

    listar = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            return reply.send(await analiseFoliarService.listar(request.user.id));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao listar análises foliares.");
        }
    };

    buscar = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await analiseFoliarService.buscar(request.user.id, Number(request.params.id)),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao buscar análise foliar.");
        }
    };

    imagem = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            const imagem = await analiseFoliarService.buscarImagem(
                request.user.id,
                Number(request.params.id),
            );
            return reply
                .type(imagem.imagem_mime)
                .header("Cache-Control", "private, max-age=3600")
                .send(Buffer.from(imagem.imagem_preview));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao buscar foto da análise.");
        }
    };

    feedback = async (
        request: FastifyRequest<{
            Params: { id: string };
            Body: FeedbackAnaliseFoliarBody;
        }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await analiseFoliarService.registrarFeedback(
                    request.user.id,
                    Number(request.params.id),
                    request.body,
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao registrar feedback.");
        }
    };

    remover = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            await analiseFoliarService.remover(request.user.id, Number(request.params.id));
            return reply.status(204).send();
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao remover análise foliar.");
        }
    };

    capacidades = async (_request: FastifyRequest, reply: FastifyReply) =>
        reply.send(analiseFoliarService.capacidades());
}

export const analiseFoliarController = new AnaliseFoliarController();
