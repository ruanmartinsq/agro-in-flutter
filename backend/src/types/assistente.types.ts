export type PapelMensagemAssistente = "usuario" | "assistente";

export interface MensagemAssistente {
    papel: PapelMensagemAssistente;
    conteudo: string;
}
export interface PerguntarAssistenteBody {
    mensagem: string;
    historico?: MensagemAssistente[];
}

export interface FonteAssistente {
    id: number;
    titulo: string;
    organizacao: string;
    url: string;
}
