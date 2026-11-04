export interface RelatorioResponse {
    propriedade: string;
    financeiro: {
        entradas: number;
        saidas: number;
        saldo: number;
    };
    producao: {
        total: number;
    };
    estoque: {
        totalItens: number;
    };
}