import { prisma } from "../lib/prisma.js"
import { AppError } from "../errors/AppError.js"
import { TipoFinanceiro } from "@prisma/client"
import { RelatorioResponse } from "../types/relatorios.types.js"
export class RelatorioError extends AppError {}

class RelatorioService {

    private assertPropriedadePertenceAoUsuario = async (usuarioId: number, propriedadeId: number) => {
        const propriedade = await prisma.propriedade.findFirst({
            where: { id: propriedadeId, usuario_id: usuarioId },
        });

        if (!propriedade) {
            throw new RelatorioError("Propriedade não encontrada.", 404)
        }

        return propriedade
    }

    private getDadosRelatorios = async (propriedadeId: number, propriedadeNome: string) => {

        const [entradas, saidas, totalProducoes, totalItensEstoque] = await Promise.all([
            prisma.financeiro.aggregate({
                _sum: { valor: true },
                where: { propriedade_id: propriedadeId, tipo: TipoFinanceiro.entrada },
            }),
            prisma.financeiro.aggregate({
                _sum: { valor: true },
                where: { propriedade_id: propriedadeId, tipo: TipoFinanceiro.saida },
            }),
            prisma.producao.count({
                where: { propriedade_id: propriedadeId },
            }),
            prisma.estoque.count({
                where: { propriedade_id: propriedadeId },
            }),
        ])

        const totalEntrada = entradas._sum.valor ?? 0
        const totalSaida = saidas._sum.valor ?? 0

        return {
            propriedade: propriedadeNome,
            financeiro: {
                entradas: totalEntrada,
                saidas: totalSaida,
                saldo: totalEntrada - totalSaida,
            },
            producao: { total: totalProducoes },
            estoque: { totalItens: totalItensEstoque },
        }

    }

    gerarRelatorio = async (usuarioId: number, propriedadeId: number): Promise<RelatorioResponse> => {

        const propriedade = await this.assertPropriedadePertenceAoUsuario(propriedadeId, usuarioId)

        return this.getDadosRelatorios(propriedadeId, propriedade.nome)
    }
}

export const relatorioService = new RelatorioService()