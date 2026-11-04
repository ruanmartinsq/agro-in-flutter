export interface CreateProducaoBody {
    propriedade_id: number
    tipo: string
    area_utilizada: number
    quantidade: number
    data_inicio: string
    data_fim: string
    status: string
}

export interface UpdateProducaoBody {
    propriedade_id?: number
    tipo?: string
    area_utilizada?: number
    quantidade?: number
    data_inicio?: string
    data_fim?: string
    status?: string
}