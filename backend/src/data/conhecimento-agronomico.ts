export interface DocumentoAgronomico {
    id: string;
    titulo: string;
    organizacao: string;
    url: string;
    palavrasChave: string[];
    conteudo: string;
}

/**
 * Base inicial, curta e auditável. Ela contém sínteses próprias e links para
 * fontes públicas, não cópias integrais de livros ou cartilhas.
 */
export const CONHECIMENTO_AGRONOMICO: DocumentoAgronomico[] = [
    {
        id: "diagnostico-responsavel",
        titulo: "Conteúdos técnicos da Embrapa",
        organizacao: "Embrapa",
        url: "https://www.embrapa.br/conteudos-tecnicos",
        palavrasChave: [
            "diagnostico",
            "doenca",
            "sintoma",
            "folha",
            "fungo",
            "bacteria",
            "virus",
            "praga",
            "estresse",
        ],
        conteudo:
            "Sintomas visuais semelhantes podem ter causas diferentes. Uma orientação remota deve ser tratada como hipótese. Para confirmar, registre cultura, cultivar, estágio, distribuição no talhão, face da folha, clima recente e evolução; quando necessário, encaminhe amostras a laboratório ou profissional habilitado.",
    },
    {
        id: "manejo-integrado-pragas",
        titulo: "Manejo Integrado de Pragas",
        organizacao: "Embrapa",
        url: "https://www.embrapa.br/tema-manejo-integrado-de-pragas",
        palavrasChave: [
            "praga",
            "inseto",
            "lagarta",
            "percevejo",
            "controle",
            "monitoramento",
            "manejo",
            "mip",
        ],
        conteudo:
            "O manejo integrado combina monitoramento, identificação correta, nível de ação e métodos culturais, biológicos e químicos. A presença de um organismo não significa automaticamente necessidade de aplicação. Decisões devem considerar a cultura, o estágio, a população observada e as recomendações regionais.",
    },
    {
        id: "agrofit",
        titulo: "Sistema Agrofit — produtos registrados",
        organizacao: "Ministério da Agricultura e Pecuária",
        url: "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons",
        palavrasChave: [
            "agrotoxico",
            "fungicida",
            "inseticida",
            "herbicida",
            "produto",
            "dose",
            "aplicacao",
            "registro",
            "defensivo",
        ],
        conteudo:
            "Produtos fitossanitários só devem ser considerados quando registrados para a combinação de cultura e alvo, conforme o Agrofit, a bula vigente e o receituário agronômico. A escolha, dose, intervalo, equipamento e período de carência não devem ser prescritos por um assistente genérico.",
    },
    {
        id: "solos",
        titulo: "Solos brasileiros",
        organizacao: "Embrapa",
        url: "https://www.embrapa.br/tema-solos-brasileiros",
        palavrasChave: [
            "solo",
            "fertilidade",
            "nutricao",
            "nutriente",
            "adubo",
            "adubacao",
            "npk",
            "ph",
            "calagem",
            "gessagem",
            "amostragem",
        ],
        conteudo:
            "A aparência da folha pode levantar suspeitas de deficiência, mas não mede fertilidade, pH ou disponibilidade de nutrientes no solo. Recomendação de corretivo ou fertilizante exige amostragem representativa, análise de laboratório, cultura, produtividade esperada, histórico e referência regional.",
    },
    {
        id: "infoteca",
        titulo: "Infoteca-e: Informação Tecnológica em Agricultura",
        organizacao: "Embrapa",
        url: "https://www.infoteca.cnptia.embrapa.br/infoteca/",
        palavrasChave: [
            "cartilha",
            "manual",
            "publicacao",
            "livro",
            "pesquisa",
            "tecnologia",
            "cultivo",
            "producao",
        ],
        conteudo:
            "A Infoteca-e reúne publicações técnicas da Embrapa. Materiais devem ser selecionados por cultura, região e data, preservando autoria e licença. A base do assistente deve guardar sínteses próprias e referência para o documento original.",
    },
    {
        id: "amostragem-area",
        titulo: "Boas práticas para observação no campo",
        organizacao: "Agro.in — síntese técnica",
        url: "https://www.embrapa.br/conteudos-tecnicos",
        palavrasChave: [
            "talhao",
            "area",
            "amostra",
            "amostragem",
            "gps",
            "vistoria",
            "ponto",
            "monitoramento",
            "comparacao",
        ],
        conteudo:
            "Para acompanhar uma área, use pontos georreferenciados ou referências fixas, repita horário e enquadramento quando possível e registre clima e manejo. Evite concluir sobre todo o talhão com uma única planta; distribua observações e separe áreas visualmente distintas.",
    },
    {
        id: "estresse-hidrico",
        titulo: "Água na agricultura",
        organizacao: "Embrapa",
        url: "https://www.embrapa.br/tema-agua-na-agricultura",
        palavrasChave: [
            "agua",
            "seca",
            "murcha",
            "irrigacao",
            "umidade",
            "chuva",
            "estresse",
            "hidrico",
        ],
        conteudo:
            "Murcha, enrolamento e amarelecimento podem estar ligados a estresse hídrico, mas também a raízes, compactação, patógenos e fitotoxicidade. Observe umidade em profundidade, padrão no terreno, raízes e histórico de chuva ou irrigação antes de intervir.",
    },
];
