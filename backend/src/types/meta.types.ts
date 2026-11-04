export interface CreateMetaBody {
    propriedade_id: number
    descricao: string
    categoria?: string
    valor_alvo?: number
    valor_atual?: number
    unidade?: string
    responsavel?: string
    prazo: string
    status?: string
}

export interface UpdateMetaBody {
    descricao?: string
    categoria?: string
    valor_alvo?: number
    valor_atual?: number
    unidade?: string
    responsavel?: string
    prazo?: string
    status?: string
}
