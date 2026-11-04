export interface CreatePropertyBody {
    nome: string;
    area_total: number;
    tipo_producao: string;
    localizacao: string;
}

export interface UpdatePropertyBody {
    nome?: string;
    area_total?: number;
    tipo_producao?: string;
    localizacao?: string;
}