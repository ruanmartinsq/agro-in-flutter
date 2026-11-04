import type {
    HipoteseFoliar,
    MetricasVisuais,
    RecomendacaoFoliar,
    ResultadoDiagnostico,
} from "../types/analise-foliar.types.js";

interface EntradaDiagnostico {
    imagem: Buffer;
    qualidade: "boa" | "aceitavel" | "refazer";
    alertasQualidade: string[];
    metricas: MetricasVisuais;
    latitude?: number;
    longitude?: number;
}

type Registro = Record<string, unknown>;

const comoRegistro = (valor: unknown): Registro =>
    typeof valor === "object" && valor !== null && !Array.isArray(valor)
        ? (valor as Registro)
        : {};

const comoArray = (valor: unknown): unknown[] => (Array.isArray(valor) ? valor : []);
const comoTexto = (valor: unknown): string | undefined =>
    typeof valor === "string" && valor.trim() ? valor.trim() : undefined;
const comoNumero = (valor: unknown): number | undefined =>
    typeof valor === "number" && Number.isFinite(valor) ? valor : undefined;

const traduzirNomeConhecido = (nome: string) => {
    const traducoes: Record<string, string> = {
        healthy: "aparentemente saudável",
        "nutrient deficiency": "possível deficiência nutricional",
        "water stress": "possível estresse hídrico",
        "sunscald": "possível queimadura solar",
    };

    return traducoes[nome.toLowerCase()] ?? nome;
};

const categoriaDaHipotese = (nome: string, tipo?: string) => {
    const combinado = `${nome} ${tipo ?? ""}`.toLowerCase();
    if (combinado.includes("healthy") || combinado.includes("saud")) return "saudavel";
    if (combinado.includes("nutrient") || combinado.includes("defici") || combinado.includes("abiotic")) return "nutricional_ou_abiotico";
    if (combinado.includes("fung") || combinado.includes("chromista") || combinado.includes("oomyc")) return "fungo_ou_oomiceto";
    if (combinado.includes("bacter")) return "bacteria";
    if (combinado.includes("virus") || combinado.includes("viral")) return "virus";
    if (combinado.includes("pest") || combinado.includes("insect") || combinado.includes("mite")) return "praga";
    return "doenca_ou_estresse";
};

const statusDaCategoria = (categoria: string) => {
    const status: Record<string, string> = {
        saudavel: "aparentemente_saudavel",
        nutricional_ou_abiotico: "possivel_estresse_nutricional",
        fungo_ou_oomiceto: "possivel_doenca_fungica",
        bacteria: "possivel_doenca_bacteriana",
        virus: "possivel_doenca_viral",
        praga: "possivel_praga",
        doenca_ou_estresse: "possivel_doenca_ou_estresse",
    };

    return status[categoria] ?? "inconclusivo";
};

const perguntasPorCategoria = (categoria: string): string[] => {
    if (categoria === "fungo_ou_oomiceto") {
        return [
            "As manchas aumentaram depois de chuva, irrigação ou noites úmidas?",
            "Há pó, mofo ou estruturas esbranquiçadas no verso da folha?",
            "As lesões aparecem também em caules, frutos ou folhas vizinhas?",
            "O tecido ao redor da mancha parece úmido, oleoso ou com borda definida?",
        ];
    }
    if (categoria === "nutricional_ou_abiotico") {
        return [
            "O sintoma começou nas folhas mais velhas ou nas folhas mais novas?",
            "O padrão aparece em várias plantas do talhão ou apenas em pontos isolados?",
            "Houve seca, encharcamento, geada, calor intenso ou aplicação recente?",
            "Você possui análise de solo e análise foliar recentes deste talhão?",
        ];
    }
    if (categoria === "saudavel") {
        return [
            "A coloração e o vigor são semelhantes nas outras plantas do talhão?",
            "Há manchas ou deformações no verso da folha que não aparecem nesta foto?",
            "O crescimento e a produção seguem o esperado para a fase da cultura?",
        ];
    }

    return [
        "O sintoma está se espalhando para plantas vizinhas?",
        "Há insetos, teias, ovos, perfurações ou secreções no verso da folha?",
        "O mesmo padrão aparece em caules, frutos ou raízes?",
        "Quando o sintoma começou e qual manejo foi realizado antes dele?",
    ];
};

const recomendacoesPorCategoria = (categoria: string): RecomendacaoFoliar[] => {
    const comuns: RecomendacaoFoliar[] = [
        {
            etapa: "agora",
            titulo: "Marque a planta e registre o talhão",
            descricao: "Tire fotos do verso da folha, da planta inteira e de plantas vizinhas antes de intervir.",
        },
    ];

    if (categoria === "saudavel") {
        return [
            {
                etapa: "agora",
                titulo: "Mantenha o manejo e o monitoramento",
                descricao: "Compare semanalmente folhas da mesma idade e registre mudanças de cor, vigor e presença de pragas.",
            },
            {
                etapa: "confirmacao",
                titulo: "Observe o verso e o crescimento novo",
                descricao: "Alguns sintomas começam discretos; confirme em folhas novas, caules e pontos diferentes do talhão.",
            },
            {
                etapa: "laboratorio",
                titulo: "Use análises periódicas",
                descricao: "Análises de solo e tecido foliar continuam necessárias para acompanhar fertilidade e nutrição.",
            },
        ];
    }

    if (categoria === "fungo_ou_oomiceto") {
        return [
            ...comuns,
            {
                etapa: "agora",
                titulo: "Reduza a dispersão até confirmar",
                descricao: "Evite manusear plantas molhadas, higienize ferramentas e não transporte tecido suspeito entre talhões.",
            },
            {
                etapa: "confirmacao",
                titulo: "Confirme com assistência técnica",
                descricao: "Colete amostras representativas e confirme o agente; sintomas fúngicos podem se confundir com bactéria e estresse.",
            },
            {
                etapa: "laboratorio",
                titulo: "Consulte o receituário e o Agrofit",
                descricao: "Qualquer fungicida deve estar registrado para cultura e alvo e ser prescrito por profissional habilitado.",
            },
        ];
    }

    if (categoria === "nutricional_ou_abiotico") {
        return [
            ...comuns,
            {
                etapa: "agora",
                titulo: "Cheque água, raízes e distribuição do sintoma",
                descricao: "Verifique irrigação, drenagem, compactação e se o padrão ocorre em reboleiras ou no talhão inteiro.",
            },
            {
                etapa: "confirmacao",
                titulo: "Faça amostragem padronizada",
                descricao: "Registre cultura, variedade, fase e posição da folha; esses dados mudam a interpretação nutricional.",
            },
            {
                etapa: "laboratorio",
                titulo: "Analise solo e tecido antes de adubar",
                descricao: "A foto sugere estresse visual, mas não mede N, P, K ou pH. Não aplique dose de adubo só com esta triagem.",
            },
        ];
    }

    return [
        ...comuns,
        {
            etapa: "agora",
            titulo: "Não aplique produto por tentativa",
            descricao: "Isole a hipótese e evite misturas de defensivos ou fertilizantes antes da confirmação.",
        },
        {
            etapa: "confirmacao",
            titulo: "Compare plantas afetadas e sadias",
            descricao: "Fotografe folhas de mesma idade e procure vetores, lesões no caule, raízes e histórico do clima.",
        },
        {
            etapa: "laboratorio",
            titulo: "Encaminhe amostra quando houver avanço",
            descricao: "Se o sintoma se espalhar ou houver risco de perda, procure laboratório fitopatológico e responsável técnico.",
        },
    ];
};

const triagemVisual = (entrada: EntradaDiagnostico, avisosExtras: string[] = []): ResultadoDiagnostico => {
    const { metricas, qualidade, alertasQualidade } = entrada;
    let status = "inconclusivo";
    let nome = "sinais visuais inconclusivos";
    let categoria = "doenca_ou_estresse";
    let confianca = 0.28;
    let descricao =
        "A pré-análise de cor e qualidade não encontrou um padrão suficientemente específico para classificar a causa.";

    if (qualidade === "refazer") {
        nome = "foto precisa ser refeita";
        descricao = "A iluminação, o foco ou o enquadramento reduzem a confiabilidade da triagem.";
        confianca = 0.12;
    } else if (metricas.tecido_marrom >= 0.32 || metricas.tecido_escuro >= 0.38) {
        status = "possivel_necrose_ou_ressecamento";
        nome = "possível necrose ou ressecamento";
        categoria = "doenca_ou_estresse";
        confianca = 0.48;
        descricao =
            "Há proporção relevante de tecido marrom ou escuro. Isso pode ocorrer por doença, dano físico, sol, água ou senescência.";
    } else if (metricas.tecido_amarelado >= 0.28) {
        status = "possivel_estresse_nutricional";
        nome = "possível clorose ou estresse abiótico";
        categoria = "nutricional_ou_abiotico";
        confianca = 0.46;
        descricao =
            "Há amarelecimento visível. A foto não distingue deficiência nutricional de raiz, água, fitotoxicidade ou doença.";
    } else if (metricas.tecido_verde >= 0.68 && metricas.tecido_marrom < 0.12) {
        status = "aparentemente_saudavel";
        nome = "tecido predominantemente verde";
        categoria = "saudavel";
        confianca = 0.52;
        descricao =
            "A cor dominante é compatível com tecido verde, sem sinal cromático forte nesta foto. Sintomas iniciais ainda podem não aparecer.";
    }

    return {
        status_geral: status,
        confianca,
        origem: "triagem_visual",
        hipoteses: [
            {
                nome,
                categoria,
                probabilidade: confianca,
                descricao,
                sintomas: [],
            },
        ],
        recomendacoes: recomendacoesPorCategoria(categoria),
        perguntas: perguntasPorCategoria(categoria),
        avisos: [
            ...alertasQualidade,
            "A triagem visual local avalia qualidade e padrões de cor; ela não identifica espécie, fungo, bactéria ou vírus.",
            "A imagem não estima nutrientes do solo nem substitui análise química de solo e tecido foliar.",
            ...avisosExtras,
        ],
    };
};

const normalizarHipotese = (sugestao: unknown): HipoteseFoliar | null => {
    const item = comoRegistro(sugestao);
    const nomeOriginal = comoTexto(item.name);
    const probabilidade = comoNumero(item.probability);

    if (!nomeOriginal || probabilidade === undefined) return null;

    const detalhes = comoRegistro(item.details);
    const tipo = comoTexto(detalhes.type);
    const sintomasRegistro = comoRegistro(detalhes.symptoms);
    const sintomas = Object.entries(sintomasRegistro)
        .slice(0, 6)
        .map(([rotulo, valor]) => {
            const descricao = comoTexto(valor);
            return descricao ? `${rotulo}: ${descricao}` : rotulo;
        });
    const imagensSemelhantes = comoArray(item.similar_images)
        .slice(0, 2)
        .map((imagem) => {
            const registro = comoRegistro(imagem);
            const url = comoTexto(registro.url_small) ?? comoTexto(registro.url);
            if (!url) return null;
            const citacao = comoTexto(registro.citation);
            const licenca = comoTexto(registro.license_name);
            return {
                url,
                ...(citacao ? { citacao } : {}),
                ...(licenca ? { licenca } : {}),
            };
        })
        .filter((imagem): imagem is NonNullable<typeof imagem> => imagem !== null);

    const nomeCientifico = comoTexto(item.scientific_name);
    const descricao = comoTexto(detalhes.description) ?? comoTexto(comoRegistro(detalhes.wiki_description).value);

    return {
        nome: traduzirNomeConhecido(nomeOriginal),
        ...(nomeCientifico ? { nome_cientifico: nomeCientifico } : {}),
        categoria: categoriaDaHipotese(nomeOriginal, tipo),
        probabilidade,
        ...(descricao ? { descricao } : {}),
        sintomas,
        ...(imagensSemelhantes.length ? { imagens_semelhantes: imagensSemelhantes } : {}),
    };
};

const categoriaDaDoencaPlantNet = (descricao: string) => {
    const texto = descricao
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .toLowerCase();

    if (
        [
            "aphid",
            "aphis",
            "pulg",
            "whitefly",
            "thrips",
            "mite",
            "acari",
            "coccid",
            "insect",
            "beetle",
            "weevil",
            "caterpillar",
            "borer",
            "nematod",
        ].some((termo) => texto.includes(termo))
    ) {
        return "praga";
    }
    if (
        [
            "virus",
            "viral",
            "mosaic",
            "mosaico",
            "begomovirus",
            "potyvirus",
            "tospovirus",
        ].some((termo) => texto.includes(termo))
    ) {
        return "virus";
    }
    if (
        [
            "bacter",
            "xanthomonas",
            "pseudomonas",
            "ralstonia",
            "erwinia",
            "agrobacterium",
        ].some((termo) => texto.includes(termo))
    ) {
        return "bacteria";
    }
    if (
        [
            "fung",
            "oomyc",
            "mildew",
            "mildi",
            "oidio",
            "rust",
            "ferrug",
            "anthrac",
            "antrac",
            "fusarium",
            "alternaria",
            "botrytis",
            "phytophthora",
            "pythium",
            "rhizoctonia",
            "sclerot",
            "cercospora",
            "colletotrichum",
            "elsinoe",
            "tranzschelia",
            "septoria",
        ].some((termo) => texto.includes(termo))
    ) {
        return "fungo_ou_oomiceto";
    }

    return "doenca_ou_estresse";
};

const normalizarHipotesePlantNet = (resultado: unknown): HipoteseFoliar | null => {
    const item = comoRegistro(resultado);
    const codigoEppo = comoTexto(item.name);
    const descricaoOriginal = comoTexto(item.description);
    const probabilidade = comoNumero(item.score);

    if (!codigoEppo || !descricaoOriginal || probabilidade === undefined) return null;

    const categoria = categoriaDaDoencaPlantNet(descricaoOriginal);
    const prefixos: Record<string, string> = {
        praga: "Possível praga",
        virus: "Possível doença viral",
        bacteria: "Possível doença bacteriana",
        fungo_ou_oomiceto: "Possível doença fúngica",
        doenca_ou_estresse: "Possível doença ou agente associado",
    };

    return {
        nome: `${prefixos[categoria] ?? prefixos.doenca_ou_estresse}: ${descricaoOriginal}`,
        categoria,
        probabilidade,
        descricao:
            `Correspondência visual sugerida pelo Pl@ntNet Diseases. Código EPPO: ${codigoEppo}. ` +
            "Confirme a cultura, a distribuição dos sintomas e os sinais observados antes de qualquer manejo.",
        sintomas: [],
    };
};

class DiagnosticoFoliarService {
    private analisarComPlantNet = async (
        entrada: EntradaDiagnostico,
        apiKey: string,
    ): Promise<ResultadoDiagnostico> => {
        const parametros = new URLSearchParams({
            "api-key": apiKey,
            "include-related-images": "false",
            "nb-results": "3",
            lang: "en",
        });
        const corpo = new FormData();
        corpo.append("organs", "leaf");
        corpo.append(
            "images",
            new Blob([new Uint8Array(entrada.imagem)], { type: "image/jpeg" }),
            "folha.jpg",
        );

        const resposta = await fetch(
            `https://my-api.plantnet.org/v2/diseases/identify?${parametros.toString()}`,
            {
                method: "POST",
                body: corpo,
                signal: AbortSignal.timeout(20_000),
            },
        );

        if (!resposta.ok) {
            const detalhe = (await resposta.text()).slice(0, 180);
            const motivo =
                resposta.status === 429
                    ? "cota diária esgotada"
                    : `resposta ${resposta.status}${detalhe ? `: ${detalhe}` : ""}`;
            throw new Error(`Pl@ntNet Diseases indisponível (${motivo})`);
        }

        const bruto = comoRegistro(await resposta.json());
        const resultados = comoArray(bruto.results);
        const hipoteses = resultados
            .map(normalizarHipotesePlantNet)
            .filter((item): item is HipoteseFoliar => item !== null)
            .slice(0, 3);
        const primeira = hipoteses[0];

        if (!primeira) {
            throw new Error("Pl@ntNet Diseases não retornou uma hipótese compatível");
        }

        const limiteConfigurado = Number(process.env.PLANTNET_MIN_SCORE ?? "0.35");
        const limiteConfianca =
            Number.isFinite(limiteConfigurado) &&
            limiteConfigurado >= 0.1 &&
            limiteConfigurado <= 0.95
                ? limiteConfigurado
                : 0.35;

        if (primeira.probabilidade < limiteConfianca) {
            throw new Error(
                `Pl@ntNet Diseases retornou baixa confiança (${Math.round(primeira.probabilidade * 100)}%)`,
            );
        }

        const versao = comoTexto(bruto.version);
        const restante = comoNumero(bruto.remainingIdentificationRequests);
        const codigoEppo = comoTexto(comoRegistro(resultados[0]).name);
        const avisos = [
            ...entrada.alertasQualidade,
            "O Pl@ntNet Diseases cobre uma lista ainda limitada de culturas e patologias; ausência de resultado não comprova que a folha está saudável.",
            "As hipóteses são probabilísticas. Compare as alternativas e confirme os sintomas no campo.",
            "Recomendações químicas exigem registro para cultura/alvo e receituário de profissional habilitado.",
            "A foto não mede N, P, K, pH ou fertilidade do solo; confirme nutrição com análises de solo e tecido.",
            ...(restante !== undefined
                ? [`Cota Pl@ntNet disponível nesta chave hoje: ${restante} identificações.`]
                : []),
        ];

        return {
            status_geral: statusDaCategoria(primeira.categoria),
            confianca: primeira.probabilidade,
            origem: "plantnet",
            ...(codigoEppo ? { referencia_provedor: `EPPO:${codigoEppo}` } : {}),
            ...(versao ? { versao_modelo: versao } : {}),
            hipoteses,
            recomendacoes: recomendacoesPorCategoria(primeira.categoria),
            perguntas: perguntasPorCategoria(primeira.categoria),
            avisos,
        };
    };

    private analisarComCropHealth = async (
        entrada: EntradaDiagnostico,
        apiKey: string,
    ): Promise<ResultadoDiagnostico> => {
        const parametros = new URLSearchParams({
            details: "type,common_names,description,symptoms,severity,spreading,treatment,eppo_code",
            language: "pt",
        });
        const corpo: Record<string, unknown> = {
            images: [`data:image/jpeg;base64,${entrada.imagem.toString("base64")}`],
            similar_images: true,
        };

        if (entrada.latitude !== undefined) corpo.latitude = entrada.latitude;
        if (entrada.longitude !== undefined) corpo.longitude = entrada.longitude;

        const resposta = await fetch(
            `https://crop.kindwise.com/api/v1/identification?${parametros.toString()}`,
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Api-Key": apiKey,
                },
                body: JSON.stringify(corpo),
                signal: AbortSignal.timeout(20_000),
            },
        );

        if (!resposta.ok) {
            const mensagem = await resposta.text();
            throw new Error(`crop.health respondeu ${resposta.status}: ${mensagem.slice(0, 180)}`);
        }

        const bruto = comoRegistro(await resposta.json());
        const resultado = comoRegistro(bruto.result);
        const doencas = comoRegistro(resultado.disease);
        const culturas = comoRegistro(resultado.crop);
        const hipoteses = comoArray(doencas.suggestions)
            .map(normalizarHipotese)
            .filter((item): item is HipoteseFoliar => item !== null)
            .slice(0, 3);

        if (!hipoteses.length) {
            throw new Error("crop.health não retornou hipóteses.");
        }

        const primeira = hipoteses[0];
        if (!primeira) throw new Error("crop.health retornou resultado incompleto.");

        const cultura = comoRegistro(comoArray(culturas.suggestions)[0]);
        const culturaNome = comoTexto(cultura.name);
        const culturaCientifica = comoTexto(cultura.scientific_name);
        const culturaConfianca = comoNumero(cultura.probability);
        const isPlanta = comoNumero(comoRegistro(resultado.is_plant).probability);
        const referencia = comoTexto(bruto.access_token);
        const versao = comoTexto(bruto.model_version);
        const avisos = [
            ...entrada.alertasQualidade,
            "As hipóteses são probabilísticas. Compare as alternativas e confirme sintomas no campo.",
            "Recomendações químicas exigem registro para cultura/alvo e receituário de profissional habilitado.",
            "A foto não mede N, P, K, pH ou fertilidade do solo; confirme nutrição com análises de solo e tecido.",
        ];

        if (isPlanta !== undefined && isPlanta < 0.5) {
            avisos.unshift("O sistema encontrou baixa probabilidade de haver uma planta na foto.");
        }

        return {
            status_geral: statusDaCategoria(primeira.categoria),
            confianca: primeira.probabilidade,
            origem: "crop_health",
            ...(referencia ? { referencia_provedor: referencia } : {}),
            ...(versao ? { versao_modelo: versao } : {}),
            ...(isPlanta !== undefined ? { is_planta: isPlanta } : {}),
            ...(culturaNome ? { cultura_detectada: culturaNome } : {}),
            ...(culturaCientifica ? { cultura_cientifica: culturaCientifica } : {}),
            ...(culturaConfianca !== undefined ? { cultura_confianca: culturaConfianca } : {}),
            hipoteses,
            recomendacoes: recomendacoesPorCategoria(primeira.categoria),
            perguntas: perguntasPorCategoria(primeira.categoria),
            avisos,
        };
    };

    analisar = async (entrada: EntradaDiagnostico): Promise<ResultadoDiagnostico> => {
        const plantNetApiKey = process.env.PLANTNET_API_KEY?.trim();
        const cropHealthApiKey = process.env.KINDWISE_CROP_HEALTH_API_KEY?.trim();

        if (entrada.qualidade === "refazer") {
            return triagemVisual(entrada);
        }

        const avisosFallback: string[] = [];

        if (plantNetApiKey) {
            try {
                return await this.analisarComPlantNet(entrada, plantNetApiKey);
            } catch (error) {
                const mensagem = error instanceof Error ? error.message : "falha desconhecida";
                avisosFallback.push(`O Pl@ntNet não concluiu esta tentativa (${mensagem}).`);
            }
        }

        if (cropHealthApiKey) {
            try {
                return await this.analisarComCropHealth(entrada, cropHealthApiKey);
            } catch (error) {
                const mensagem = error instanceof Error ? error.message : "falha desconhecida";
                avisosFallback.push(`O crop.health não concluiu esta tentativa (${mensagem}).`);
            }
        }

        return triagemVisual(
            entrada,
            avisosFallback.length
                ? [
                    ...avisosFallback,
                    "A triagem visual local foi preservada nesta análise.",
                ]
                : [],
        );
    };
}

export const diagnosticoFoliarService = new DiagnosticoFoliarService();
