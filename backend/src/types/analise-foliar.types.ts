export interface CriarAnaliseFoliarBody {
    imagem: string;
    cultura?: string;
    propriedade_id?: number;
    latitude?: number;
    longitude?: number;
    precisao_metros?: number;
    observacoes?: string;
    consentimento: boolean;
    caso_id?: number;
    ponto_vistoria_id?: number;
}

export interface FeedbackAnaliseFoliarBody {
    util: boolean;
    diagnostico_confirmado?: string;
}

export interface CriarCasoFoliarBody {
    analise_id: number;
    titulo?: string;
    tratamento?: string;
    proxima_revisao_em?: string;
}

export interface AtualizarCasoFoliarBody {
    titulo?: string;
    tratamento?: string;
    proxima_revisao_em?: string | null;
}

export interface CriarVistoriaAreaBody {
    nome: string;
    propriedade_id?: number;
    cultura?: string;
    objetivo?: string;
}

export interface CriarPontoVistoriaBody {
    nome: string;
    setor?: string;
}

export interface AtualizarLocalizacaoPontoBody {
    latitude: number;
    longitude: number;
    precisao_metros?: number;
}

export interface MetricasVisuais {
    largura: number;
    altura: number;
    luminosidade: number;
    contraste: number;
    foco_aproximado: number;
    area_foliar_aproximada: number;
    tecido_verde: number;
    tecido_amarelado: number;
    tecido_marrom: number;
    tecido_escuro: number;
}

export interface HipoteseFoliar {
    nome: string;
    nome_cientifico?: string;
    categoria: string;
    probabilidade: number;
    descricao?: string;
    sintomas: string[];
    imagens_semelhantes?: Array<{
        url: string;
        citacao?: string;
        licenca?: string;
    }>;
}

export interface RecomendacaoFoliar {
    etapa: "agora" | "confirmacao" | "laboratorio";
    titulo: string;
    descricao: string;
}

export interface ResultadoDiagnostico {
    status_geral: string;
    confianca: number;
    origem: "triagem_visual" | "plantnet" | "crop_health";
    referencia_provedor?: string;
    versao_modelo?: string;
    is_planta?: number;
    cultura_detectada?: string;
    cultura_cientifica?: string;
    cultura_confianca?: number;
    hipoteses: HipoteseFoliar[];
    recomendacoes: RecomendacaoFoliar[];
    perguntas: string[];
    avisos: string[];
}
