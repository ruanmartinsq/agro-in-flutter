import type { Prisma } from "@prisma/client";

type MetricasComparaveis = {
    tecido_verde: number;
    tecido_amarelado: number;
    tecido_marrom: number;
    tecido_escuro: number;
};

const numero = (valor: unknown) =>
    typeof valor === "number" && Number.isFinite(valor) ? valor : 0;

const metricas = (valor: Prisma.JsonValue): MetricasComparaveis => {
    const registro =
        valor && typeof valor === "object" && !Array.isArray(valor)
            ? (valor as Record<string, unknown>)
            : {};

    return {
        tecido_verde: numero(registro.tecido_verde),
        tecido_amarelado: numero(registro.tecido_amarelado),
        tecido_marrom: numero(registro.tecido_marrom),
        tecido_escuro: numero(registro.tecido_escuro),
    };
};

const arredondar = (valor: number) => Math.round(valor * 1000) / 1000;

const indiceSinais = (valor: MetricasComparaveis) =>
    valor.tecido_amarelado + valor.tecido_marrom * 0.8 + valor.tecido_escuro * 0.6;

class ComparacaoFoliarService {
    comparar = (entrada: {
        referenciaId: number;
        referenciaCriadaEm: Date;
        referenciaQualidade: string;
        referenciaMetricas: Prisma.JsonValue;
        atualQualidade: string;
        atualMetricas: Prisma.JsonValue;
    }): Prisma.InputJsonValue => {
        const anterior = metricas(entrada.referenciaMetricas);
        const atual = metricas(entrada.atualMetricas);
        const diasDesde = Math.max(
            0,
            Math.round(
                (Date.now() - entrada.referenciaCriadaEm.getTime()) / (1000 * 60 * 60 * 24),
            ),
        );

        const deltas = {
            verde: arredondar(atual.tecido_verde - anterior.tecido_verde),
            amarelado: arredondar(atual.tecido_amarelado - anterior.tecido_amarelado),
            marrom: arredondar(atual.tecido_marrom - anterior.tecido_marrom),
            escuro: arredondar(atual.tecido_escuro - anterior.tecido_escuro),
        };
        const variacaoIndice = arredondar(indiceSinais(anterior) - indiceSinais(atual));
        const inconclusivo =
            entrada.referenciaQualidade === "refazer" || entrada.atualQualidade === "refazer";

        let estado = "estavel";
        let resumo = "Os sinais visuais permaneceram próximos da foto anterior.";

        if (inconclusivo) {
            estado = "inconclusivo";
            resumo = "A qualidade de uma das fotos não permite uma comparação segura.";
        } else if (variacaoIndice >= 0.06) {
            estado = "melhora_visual";
            resumo = "Houve redução dos sinais visuais de amarelecimento, escurecimento ou necrose.";
        } else if (variacaoIndice <= -0.06) {
            estado = "piora_visual";
            resumo = "Houve aumento dos sinais visuais que merecem nova verificação em campo.";
        }

        return {
            referencia_id: entrada.referenciaId,
            dias_desde: diasDesde,
            estado,
            variacao_indice: variacaoIndice,
            deltas,
            resumo,
            aviso:
                "Comparação orientativa: fotografe folhas da mesma idade, posição e iluminação. Mudança visual não confirma cura nem substitui avaliação agronômica.",
        };
    };
}

export const comparacaoFoliarService = new ComparacaoFoliarService();
