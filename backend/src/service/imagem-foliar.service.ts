import sharp, { type Metadata } from "sharp";

import { AppError } from "../errors/AppError.js";
import type { MetricasVisuais } from "../types/analise-foliar.types.js";

const LIMITE_IMAGEM_BYTES = 6 * 1024 * 1024;

interface ImagemProcessada {
    dadosParaAnalise: Buffer;
    preview: Buffer;
    mime: "image/jpeg";
    metricas: MetricasVisuais;
    qualidade: "boa" | "aceitavel" | "refazer";
    alertas: string[];
}

const limitar = (valor: number) => Math.max(0, Math.min(1, valor));

const rgbParaHsv = (rByte: number, gByte: number, bByte: number) => {
    const r = rByte / 255;
    const g = gByte / 255;
    const b = bByte / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const delta = max - min;
    let hue = 0;

    if (delta !== 0) {
        if (max === r) hue = 60 * (((g - b) / delta) % 6);
        else if (max === g) hue = 60 * ((b - r) / delta + 2);
        else hue = 60 * ((r - g) / delta + 4);
    }

    if (hue < 0) hue += 360;

    return {
        hue,
        saturation: max === 0 ? 0 : delta / max,
        value: max,
    };
};

const extrairBuffer = (imagem: string) => {
    const correspondencia = imagem.match(
        /^data:(image\/(?:jpeg|jpg|png|webp));base64,([a-zA-Z0-9+/=\r\n]+)$/,
    );

    if (!correspondencia?.[2]) {
        throw new AppError("Envie uma foto JPEG, PNG ou WebP válida.", 400);
    }

    const buffer = Buffer.from(correspondencia[2], "base64");

    if (!buffer.length || buffer.length > LIMITE_IMAGEM_BYTES) {
        throw new AppError("A foto deve ter no máximo 6 MB.", 413);
    }

    return buffer;
};

class ImagemFoliarService {
    processar = async (imagem: string): Promise<ImagemProcessada> => {
        const original = extrairBuffer(imagem);

        let metadata: Metadata;
        try {
            metadata = await sharp(original).metadata();
        } catch {
            throw new AppError("Não foi possível ler a foto enviada.", 400);
        }

        if (!metadata.width || !metadata.height) {
            throw new AppError("A foto não possui dimensões válidas.", 400);
        }

        const dadosParaAnalise = await sharp(original)
            .rotate()
            .resize({
                width: 1280,
                height: 1280,
                fit: "inside",
                withoutEnlargement: true,
            })
            .jpeg({ quality: 84, mozjpeg: true })
            .toBuffer();

        const preview = await sharp(dadosParaAnalise)
            .resize({
                width: 720,
                height: 720,
                fit: "inside",
                withoutEnlargement: true,
            })
            .jpeg({ quality: 78, mozjpeg: true })
            .toBuffer();

        const amostra = await sharp(dadosParaAnalise)
            .resize({ width: 96, height: 96, fit: "inside" })
            .removeAlpha()
            .raw()
            .toBuffer({ resolveWithObject: true });

        const totalPixels = amostra.info.width * amostra.info.height;
        let somaLuminosidade = 0;
        let somaLuminosidadeQuadrado = 0;
        let somaGradiente = 0;
        let comparacoesGradiente = 0;
        let pixelsFolha = 0;
        let verdes = 0;
        let amarelos = 0;
        let marrons = 0;
        let escuros = 0;

        const luminosidades = new Float32Array(totalPixels);

        for (let pixel = 0; pixel < totalPixels; pixel += 1) {
            const indice = pixel * 3;
            const r = amostra.data[indice] ?? 0;
            const g = amostra.data[indice + 1] ?? 0;
            const b = amostra.data[indice + 2] ?? 0;
            const luminosidade = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
            luminosidades[pixel] = luminosidade;
            somaLuminosidade += luminosidade;
            somaLuminosidadeQuadrado += luminosidade * luminosidade;

            const hsv = rgbParaHsv(r, g, b);
            const verde = hsv.hue >= 65 && hsv.hue <= 175 && hsv.saturation >= 0.18 && hsv.value >= 0.1;
            const amarelo = hsv.hue >= 38 && hsv.hue < 65 && hsv.saturation >= 0.2 && hsv.value >= 0.22;
            const marrom = hsv.hue >= 8 && hsv.hue < 38 && hsv.saturation >= 0.18 && hsv.value >= 0.1 && hsv.value <= 0.78;
            const escuro = hsv.value < 0.2;

            if (verde || amarelo || marrom) {
                pixelsFolha += 1;
                if (verde) verdes += 1;
                else if (amarelo) amarelos += 1;
                else marrons += 1;
            }

            if (escuro) escuros += 1;
        }

        for (let y = 0; y < amostra.info.height; y += 1) {
            for (let x = 0; x < amostra.info.width; x += 1) {
                const atual = y * amostra.info.width + x;
                const luminosidadeAtual = luminosidades[atual] ?? 0;

                if (x + 1 < amostra.info.width) {
                    somaGradiente += Math.abs(luminosidadeAtual - (luminosidades[atual + 1] ?? 0));
                    comparacoesGradiente += 1;
                }
                if (y + 1 < amostra.info.height) {
                    somaGradiente += Math.abs(luminosidadeAtual - (luminosidades[atual + amostra.info.width] ?? 0));
                    comparacoesGradiente += 1;
                }
            }
        }

        const luminosidadeMedia = somaLuminosidade / totalPixels;
        const variancia = Math.max(
            0,
            somaLuminosidadeQuadrado / totalPixels - luminosidadeMedia * luminosidadeMedia,
        );
        const foco = comparacoesGradiente ? somaGradiente / comparacoesGradiente : 0;
        const baseFoliar = Math.max(pixelsFolha, 1);

        const metricas: MetricasVisuais = {
            largura: metadata.width,
            altura: metadata.height,
            luminosidade: limitar(luminosidadeMedia),
            contraste: limitar(Math.sqrt(variancia) * 3),
            foco_aproximado: limitar(foco * 8),
            area_foliar_aproximada: limitar(pixelsFolha / totalPixels),
            tecido_verde: limitar(verdes / baseFoliar),
            tecido_amarelado: limitar(amarelos / baseFoliar),
            tecido_marrom: limitar(marrons / baseFoliar),
            tecido_escuro: limitar(escuros / totalPixels),
        };

        const alertas: string[] = [];
        const menorLado = Math.min(metadata.width, metadata.height);

        if (menorLado < 480) alertas.push("A resolução está baixa; aproxime a câmera sem usar zoom digital.");
        if (metricas.luminosidade < 0.2) alertas.push("A foto está escura; fotografe em luz natural indireta.");
        if (metricas.luminosidade > 0.9) alertas.push("A foto está muito clara; evite reflexos e sol direto.");
        if (metricas.foco_aproximado < 0.12) alertas.push("O foco parece baixo; mantenha o celular firme e toque na folha.");
        if (metricas.area_foliar_aproximada < 0.08) alertas.push("A folha parece ocupar pouco espaço na foto.");

        const qualidade =
            alertas.length >= 2 || metricas.luminosidade < 0.12 || metricas.foco_aproximado < 0.06
                ? "refazer"
                : alertas.length === 1
                  ? "aceitavel"
                  : "boa";

        return {
            dadosParaAnalise,
            preview,
            mime: "image/jpeg",
            metricas,
            qualidade,
            alertas,
        };
    };
}

export const imagemFoliarService = new ImagemFoliarService();
