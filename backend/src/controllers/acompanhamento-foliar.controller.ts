import type { FastifyReply, FastifyRequest } from "fastify";

import { AppError } from "../errors/AppError.js";
import { casoFoliarService } from "../service/caso-foliar.service.js";
import { vistoriaAreaService } from "../service/vistoria-area.service.js";
import type {
    AtualizarCasoFoliarBody,
    AtualizarLocalizacaoPontoBody,
    CriarCasoFoliarBody,
    CriarPontoVistoriaBody,
    CriarVistoriaAreaBody,
} from "../types/analise-foliar.types.js";

const responderErro = (
    request: FastifyRequest,
    reply: FastifyReply,
    error: unknown,
    mensagem: string,
) => {
    if (error instanceof AppError) {
        return reply.status(error.statusCode).send({ error: error.message });
    }
    request.log.error(error);
    return reply.status(500).send({ error: mensagem });
};

class AcompanhamentoFoliarController {
    criarCaso = async (
        request: FastifyRequest<{ Body: CriarCasoFoliarBody }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply
                .status(201)
                .send(await casoFoliarService.criar(request.user.id, request.body));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao criar quarentena.");
        }
    };

    listarCasos = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            return reply.send(await casoFoliarService.listar(request.user.id));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao listar quarentenas.");
        }
    };

    buscarCaso = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await casoFoliarService.buscar(request.user.id, Number(request.params.id)),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao buscar quarentena.");
        }
    };

    atualizarCaso = async (
        request: FastifyRequest<{
            Params: { id: string };
            Body: AtualizarCasoFoliarBody;
        }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await casoFoliarService.atualizar(
                    request.user.id,
                    Number(request.params.id),
                    request.body,
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao atualizar quarentena.");
        }
    };

    encerrarCaso = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await casoFoliarService.encerrar(
                    request.user.id,
                    Number(request.params.id),
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao encerrar quarentena.");
        }
    };

    reabrirCaso = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await casoFoliarService.reabrir(
                    request.user.id,
                    Number(request.params.id),
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao reabrir quarentena.");
        }
    };

    criarVistoria = async (
        request: FastifyRequest<{ Body: CriarVistoriaAreaBody }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply
                .status(201)
                .send(await vistoriaAreaService.criar(request.user.id, request.body));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao criar vistoria.");
        }
    };

    listarVistorias = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            return reply.send(await vistoriaAreaService.listar(request.user.id));
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao listar vistorias.");
        }
    };

    buscarVistoria = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await vistoriaAreaService.buscar(
                    request.user.id,
                    Number(request.params.id),
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao buscar vistoria.");
        }
    };

    adicionarPonto = async (
        request: FastifyRequest<{
            Params: { id: string };
            Body: CriarPontoVistoriaBody;
        }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.status(201).send(
                await vistoriaAreaService.adicionarPonto(
                    request.user.id,
                    Number(request.params.id),
                    request.body,
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao adicionar ponto.");
        }
    };

    localizarPonto = async (
        request: FastifyRequest<{
            Params: { id: string; pontoId: string };
            Body: AtualizarLocalizacaoPontoBody;
        }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await vistoriaAreaService.atualizarLocalizacao(
                    request.user.id,
                    Number(request.params.id),
                    Number(request.params.pontoId),
                    request.body,
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao salvar localização.");
        }
    };

    concluirVistoria = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await vistoriaAreaService.concluir(
                    request.user.id,
                    Number(request.params.id),
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao concluir vistoria.");
        }
    };

    reabrirVistoria = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(
                await vistoriaAreaService.reabrir(
                    request.user.id,
                    Number(request.params.id),
                ),
            );
        } catch (error) {
            return responderErro(request, reply, error, "Erro ao reabrir vistoria.");
        }
    };
}

export const acompanhamentoFoliarController = new AcompanhamentoFoliarController();
