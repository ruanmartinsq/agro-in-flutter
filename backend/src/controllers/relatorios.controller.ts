import { FastifyRequest, FastifyReply } from "fastify"
import { relatorioService, RelatorioError } from "../service/relatorios.service.js"

class RelatorioController {
    gerar = async (request: FastifyRequest<{ Params: { propriedadeId: string } }>, reply: FastifyReply) => {
        try {
            const relatorio = await relatorioService.gerarRelatorio(request.user.id, Number(request.params.propriedadeId))

            return reply.send(relatorio)
        } catch (error) {
            if (error instanceof RelatorioError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao gerar relatório." })
        }
    }
}

export const relatorioController = new RelatorioController()