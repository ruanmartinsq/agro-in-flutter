import type { FastifyInstance } from "fastify";

import { acompanhamentoFoliarController } from "../controllers/acompanhamento-foliar.controller.js";
import { analiseFoliarController } from "../controllers/analise-foliar.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import type {
    AtualizarCasoFoliarBody,
    AtualizarLocalizacaoPontoBody,
    CriarAnaliseFoliarBody,
    CriarCasoFoliarBody,
    CriarPontoVistoriaBody,
    CriarVistoriaAreaBody,
    FeedbackAnaliseFoliarBody,
} from "../types/analise-foliar.types.js";

export const analiseFoliarRoutes = async (app: FastifyInstance) => {
    app.get("/capacidades", { preHandler: [authMiddleware] }, analiseFoliarController.capacidades);
    app.get("/", { preHandler: [authMiddleware] }, analiseFoliarController.listar);
    app.post<{ Body: CriarAnaliseFoliarBody }>(
        "/",
        { preHandler: [authMiddleware] },
        analiseFoliarController.criar,
    );
    app.get(
        "/quarentenas",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.listarCasos,
    );
    app.post<{ Body: CriarCasoFoliarBody }>(
        "/quarentenas",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.criarCaso,
    );
    app.get<{ Params: { id: string } }>(
        "/quarentenas/:id",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.buscarCaso,
    );
    app.patch<{
        Params: { id: string };
        Body: AtualizarCasoFoliarBody;
    }>(
        "/quarentenas/:id",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.atualizarCaso,
    );
    app.post<{ Params: { id: string } }>(
        "/quarentenas/:id/encerrar",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.encerrarCaso,
    );
    app.post<{ Params: { id: string } }>(
        "/quarentenas/:id/reabrir",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.reabrirCaso,
    );
    app.get(
        "/vistorias",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.listarVistorias,
    );
    app.post<{ Body: CriarVistoriaAreaBody }>(
        "/vistorias",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.criarVistoria,
    );
    app.get<{ Params: { id: string } }>(
        "/vistorias/:id",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.buscarVistoria,
    );
    app.post<{
        Params: { id: string };
        Body: CriarPontoVistoriaBody;
    }>(
        "/vistorias/:id/pontos",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.adicionarPonto,
    );
    app.patch<{
        Params: { id: string; pontoId: string };
        Body: AtualizarLocalizacaoPontoBody;
    }>(
        "/vistorias/:id/pontos/:pontoId/localizacao",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.localizarPonto,
    );
    app.post<{ Params: { id: string } }>(
        "/vistorias/:id/concluir",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.concluirVistoria,
    );
    app.post<{ Params: { id: string } }>(
        "/vistorias/:id/reabrir",
        { preHandler: [authMiddleware] },
        acompanhamentoFoliarController.reabrirVistoria,
    );
    app.get<{ Params: { id: string } }>(
        "/:id",
        { preHandler: [authMiddleware] },
        analiseFoliarController.buscar,
    );
    app.get<{ Params: { id: string } }>(
        "/:id/imagem",
        { preHandler: [authMiddleware] },
        analiseFoliarController.imagem,
    );
    app.patch<{
        Params: { id: string };
        Body: FeedbackAnaliseFoliarBody;
    }>(
        "/:id/feedback",
        { preHandler: [authMiddleware] },
        analiseFoliarController.feedback,
    );
    app.delete<{ Params: { id: string } }>(
        "/:id",
        { preHandler: [authMiddleware] },
        analiseFoliarController.remover,
    );
};
