import type { Prisma } from "@prisma/client";

import { AppError } from "../errors/AppError.js";
import { prisma } from "../lib/prisma.js";
import type {
    CriarAnaliseFoliarBody,
    FeedbackAnaliseFoliarBody,
} from "../types/analise-foliar.types.js";
import { comparacaoFoliarService } from "./comparacao-foliar.service.js";
import { diagnosticoFoliarService } from "./diagnostico-foliar.service.js";
import { imagemFoliarService } from "./imagem-foliar.service.js";

export class AnaliseFoliarError extends AppError {}

const paraJson = (valor: unknown): Prisma.InputJsonValue =>
    JSON.parse(JSON.stringify(valor)) as Prisma.InputJsonValue;

export const camposPublicos = {
    id: true,
    propriedade_id: true,
    caso_id: true,
    ponto_vistoria_id: true,
    etapa_acompanhamento: true,
    comparacao_anterior: true,
    cultura_informada: true,
    cultura_detectada: true,
    cultura_cientifica: true,
    cultura_confianca: true,
    status_geral: true,
    confianca: true,
    origem_diagnostico: true,
    referencia_provedor: true,
    versao_modelo: true,
    qualidade_foto: true,
    is_planta: true,
    hipoteses: true,
    recomendacoes: true,
    perguntas_confirmacao: true,
    metricas_visuais: true,
    avisos: true,
    latitude: true,
    longitude: true,
    observacoes: true,
    feedback_util: true,
    diagnostico_confirmado: true,
    imagem_mime: true,
    criado_em: true,
    atualizado_em: true,
    propriedade: {
        select: {
            id: true,
            nome: true,
        },
    },
    caso: {
        select: {
            id: true,
            titulo: true,
            status: true,
        },
    },
    ponto_vistoria: {
        select: {
            id: true,
            nome: true,
            setor: true,
            vistoria: {
                select: {
                    id: true,
                    nome: true,
                    status: true,
                },
            },
        },
    },
} satisfies Prisma.AnaliseFoliarSelect;

class AnaliseFoliarService {
    private validarPropriedade = async (usuarioId: number, propriedadeId?: number) => {
        if (propriedadeId === undefined) return;
        if (!Number.isInteger(propriedadeId) || propriedadeId <= 0) {
            throw new AnaliseFoliarError("Propriedade inválida.", 400);
        }

        const propriedade = await prisma.propriedade.findFirst({
            where: {
                id: propriedadeId,
                usuario_id: usuarioId,
            },
            select: { id: true },
        });

        if (!propriedade) {
            throw new AnaliseFoliarError("Propriedade não encontrada.", 403);
        }
    };

    private validarCoordenadas = (
        latitude?: number,
        longitude?: number,
        precisaoMetros?: number,
    ) => {
        if (latitude !== undefined && (!Number.isFinite(latitude) || latitude < -90 || latitude > 90)) {
            throw new AnaliseFoliarError("Latitude inválida.", 400);
        }
        if (longitude !== undefined && (!Number.isFinite(longitude) || longitude < -180 || longitude > 180)) {
            throw new AnaliseFoliarError("Longitude inválida.", 400);
        }
        if (
            precisaoMetros !== undefined &&
            (!Number.isFinite(precisaoMetros) || precisaoMetros < 0)
        ) {
            throw new AnaliseFoliarError("Precisão do GPS inválida.", 400);
        }
    };

    criar = async (usuarioId: number, entrada: CriarAnaliseFoliarBody) => {
        if (!entrada?.consentimento) {
            throw new AnaliseFoliarError(
                "Confirme o envio da foto para realizar e armazenar a análise.",
                400,
            );
        }
        if (!entrada.imagem) {
            throw new AnaliseFoliarError("Selecione uma foto da folha.", 400);
        }
        if (
            entrada.caso_id !== undefined &&
            entrada.ponto_vistoria_id !== undefined
        ) {
            throw new AnaliseFoliarError(
                "Escolha uma quarentena ou um ponto de vistoria, não os dois.",
                400,
            );
        }

        const caso =
            entrada.caso_id !== undefined
                ? await prisma.casoFoliar.findFirst({
                      where: {
                          id: entrada.caso_id,
                          usuario_id: usuarioId,
                          status: "em_quarentena",
                      },
                      select: {
                          id: true,
                          propriedade_id: true,
                          cultura: true,
                          analises: {
                              orderBy: { criado_em: "desc" },
                              take: 1,
                              select: {
                                  id: true,
                                  etapa_acompanhamento: true,
                                  criado_em: true,
                                  qualidade_foto: true,
                                  metricas_visuais: true,
                              },
                          },
                      },
                  })
                : null;
        if (entrada.caso_id !== undefined && !caso) {
            throw new AnaliseFoliarError("Quarentena não encontrada ou já encerrada.", 404);
        }

        const ponto =
            entrada.ponto_vistoria_id !== undefined
                ? await prisma.pontoVistoria.findFirst({
                      where: {
                          id: entrada.ponto_vistoria_id,
                          vistoria: {
                              usuario_id: usuarioId,
                              status: "em_andamento",
                          },
                      },
                      select: {
                          id: true,
                          vistoria: {
                              select: {
                                  propriedade_id: true,
                                  cultura: true,
                              },
                          },
                          analises: {
                              orderBy: { criado_em: "desc" },
                              take: 1,
                              select: {
                                  id: true,
                                  etapa_acompanhamento: true,
                                  criado_em: true,
                                  qualidade_foto: true,
                                  metricas_visuais: true,
                              },
                          },
                      },
                  })
                : null;
        if (entrada.ponto_vistoria_id !== undefined && !ponto) {
            throw new AnaliseFoliarError(
                "Ponto de vistoria não encontrado ou vistoria concluída.",
                404,
            );
        }

        const propriedadeId =
            entrada.propriedade_id ?? caso?.propriedade_id ?? ponto?.vistoria.propriedade_id;
        const propriedadeContexto = caso?.propriedade_id ?? ponto?.vistoria.propriedade_id;
        if (
            propriedadeContexto !== null &&
            propriedadeContexto !== undefined &&
            entrada.propriedade_id !== undefined &&
            entrada.propriedade_id !== propriedadeContexto
        ) {
            throw new AnaliseFoliarError(
                "A propriedade deve ser a mesma do acompanhamento selecionado.",
                400,
            );
        }

        const cultura =
            entrada.cultura?.trim().slice(0, 100) ||
            caso?.cultura ||
            ponto?.vistoria.cultura ||
            undefined;
        const observacoes = entrada.observacoes?.trim().slice(0, 600) || undefined;

        await this.validarPropriedade(usuarioId, propriedadeId ?? undefined);
        this.validarCoordenadas(
            entrada.latitude,
            entrada.longitude,
            entrada.precisao_metros,
        );

        const imagem = await imagemFoliarService.processar(entrada.imagem);
        const diagnostico = await diagnosticoFoliarService.analisar({
            imagem: imagem.dadosParaAnalise,
            qualidade: imagem.qualidade,
            alertasQualidade: imagem.alertas,
            metricas: imagem.metricas,
            ...(entrada.latitude !== undefined ? { latitude: entrada.latitude } : {}),
            ...(entrada.longitude !== undefined ? { longitude: entrada.longitude } : {}),
        });

        const anterior = caso?.analises[0] ?? ponto?.analises[0];
        const comparacao = anterior
            ? comparacaoFoliarService.comparar({
                  referenciaId: anterior.id,
                  referenciaCriadaEm: anterior.criado_em,
                  referenciaQualidade: anterior.qualidade_foto,
                  referenciaMetricas: anterior.metricas_visuais,
                  atualQualidade: imagem.qualidade,
                  atualMetricas: paraJson(imagem.metricas) as Prisma.JsonValue,
              })
            : undefined;

        return prisma.$transaction(async (tx) => {
            const analise = await tx.analiseFoliar.create({
                data: {
                    usuario_id: usuarioId,
                    ...(propriedadeId !== null && propriedadeId !== undefined
                        ? { propriedade_id: propriedadeId }
                        : {}),
                    ...(caso ? { caso_id: caso.id } : {}),
                    ...(ponto ? { ponto_vistoria_id: ponto.id } : {}),
                    etapa_acompanhamento: anterior
                        ? anterior.etapa_acompanhamento + 1
                        : 0,
                    ...(comparacao ? { comparacao_anterior: comparacao } : {}),
                    ...(cultura ? { cultura_informada: cultura } : {}),
                    ...(diagnostico.cultura_detectada
                        ? { cultura_detectada: diagnostico.cultura_detectada }
                        : {}),
                    ...(diagnostico.cultura_cientifica
                        ? { cultura_cientifica: diagnostico.cultura_cientifica }
                        : {}),
                    ...(diagnostico.cultura_confianca !== undefined
                        ? { cultura_confianca: diagnostico.cultura_confianca }
                        : {}),
                    status_geral: diagnostico.status_geral,
                    confianca: diagnostico.confianca,
                    origem_diagnostico: diagnostico.origem,
                    ...(diagnostico.referencia_provedor
                        ? { referencia_provedor: diagnostico.referencia_provedor }
                        : {}),
                    ...(diagnostico.versao_modelo
                        ? { versao_modelo: diagnostico.versao_modelo }
                        : {}),
                    qualidade_foto: imagem.qualidade,
                    ...(diagnostico.is_planta !== undefined
                        ? { is_planta: diagnostico.is_planta }
                        : {}),
                    hipoteses: paraJson(diagnostico.hipoteses),
                    recomendacoes: paraJson(diagnostico.recomendacoes),
                    perguntas_confirmacao: paraJson(diagnostico.perguntas),
                    metricas_visuais: paraJson(imagem.metricas),
                    avisos: paraJson(diagnostico.avisos),
                    ...(entrada.latitude !== undefined
                        ? { latitude: entrada.latitude }
                        : {}),
                    ...(entrada.longitude !== undefined
                        ? { longitude: entrada.longitude }
                        : {}),
                    ...(observacoes ? { observacoes } : {}),
                    imagem_preview: Uint8Array.from(imagem.preview),
                    imagem_mime: imagem.mime,
                },
                select: camposPublicos,
            });

            if (
                ponto &&
                entrada.latitude !== undefined &&
                entrada.longitude !== undefined
            ) {
                await tx.pontoVistoria.update({
                    where: { id: ponto.id },
                    data: {
                        latitude: entrada.latitude,
                        longitude: entrada.longitude,
                        ...(entrada.precisao_metros !== undefined
                            ? { precisao_metros: entrada.precisao_metros }
                            : {}),
                    },
                });
            }

            return analise;
        });
    };

    listar = async (usuarioId: number) =>
        prisma.analiseFoliar.findMany({
            where: { usuario_id: usuarioId },
            orderBy: { criado_em: "desc" },
            take: 24,
            select: camposPublicos,
        });

    buscar = async (usuarioId: number, id: number) => {
        if (!Number.isInteger(id) || id <= 0) {
            throw new AnaliseFoliarError("Análise inválida.", 400);
        }

        const analise = await prisma.analiseFoliar.findFirst({
            where: { id, usuario_id: usuarioId },
            select: camposPublicos,
        });

        if (!analise) throw new AnaliseFoliarError("Análise não encontrada.", 404);
        return analise;
    };

    buscarImagem = async (usuarioId: number, id: number) => {
        const analise = await prisma.analiseFoliar.findFirst({
            where: { id, usuario_id: usuarioId },
            select: {
                imagem_preview: true,
                imagem_mime: true,
            },
        });

        if (!analise) throw new AnaliseFoliarError("Análise não encontrada.", 404);
        return analise;
    };

    registrarFeedback = async (
        usuarioId: number,
        id: number,
        entrada: FeedbackAnaliseFoliarBody,
    ) => {
        await this.buscar(usuarioId, id);
        const diagnosticoConfirmado = entrada.diagnostico_confirmado?.trim().slice(0, 160);

        return prisma.analiseFoliar.update({
            where: { id },
            data: {
                feedback_util: Boolean(entrada.util),
                ...(diagnosticoConfirmado
                    ? { diagnostico_confirmado: diagnosticoConfirmado }
                    : { diagnostico_confirmado: null }),
            },
            select: camposPublicos,
        });
    };

    remover = async (usuarioId: number, id: number) => {
        const analise = await this.buscar(usuarioId, id);
        if (analise.caso_id || analise.ponto_vistoria_id) {
            throw new AnaliseFoliarError(
                "Esta análise faz parte de um acompanhamento e não pode ser excluída isoladamente.",
                409,
            );
        }
        await prisma.analiseFoliar.delete({ where: { id } });
    };

    capacidades = () => {
        const plantNetAtivo = Boolean(process.env.PLANTNET_API_KEY?.trim());
        const cropHealthAtivo = Boolean(process.env.KINDWISE_CROP_HEALTH_API_KEY?.trim());

        return {
            pre_analise_local: true,
            diagnostico_especializado: plantNetAtivo || cropHealthAtivo,
            provedor_especializado: plantNetAtivo
                ? "Pl@ntNet Diseases"
                : cropHealthAtivo
                    ? "crop.health"
                    : null,
            limite_gratuito_diario: plantNetAtivo ? 500 : null,
            analise_solo_por_foto: false,
            acompanhamento_temporal: true,
            vistoria_area: true,
            gps_pontos: true,
            nota:
                "A foto permite triagem visual. Nutrientes e fertilidade do solo exigem análises químicas de solo e tecido.",
        };
    };
}

export const analiseFoliarService = new AnaliseFoliarService();
