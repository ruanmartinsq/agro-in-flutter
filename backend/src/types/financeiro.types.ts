import { TipoFinanceiro } from "@prisma/client";

export interface CreateFinanceiroBody {
    propriedade_id: number;
    tipo: TipoFinanceiro;
    categoria: string;
    descricao: string;
    valor: number;
    data: string;
}

export interface UpdateFinanceiroBody {
    tipo?: TipoFinanceiro;
    categoria?: string;
    descricao?: string;
    valor?: number;
    data?: string;
}