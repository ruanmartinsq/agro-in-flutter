export interface CreateEstoqueBody {
    propriedade_id: number,
    item: string,
    categoria: string,
    quantidade: number,
    unidade: string,
    quantidade_minima: number
}

export interface UpdateEstoqueBody {
    propriedade_id?: number,
    item?: string,
    categoria?: string,
    quantidade?: number,
    unidade?: string,
    quantidade_minima?: number
}