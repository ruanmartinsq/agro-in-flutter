import bcrypt from "bcrypt";
import { createHash, randomBytes } from "node:crypto";
import jwt from "jsonwebtoken";
import "dotenv/config";
import { prisma } from "../lib/prisma.js";
import {
    RegisterBody,
    LoginBody,
    UpdateMeBody,
    UpdateSenhaBody,
    ForgotPasswordBody,
    ResetPasswordBody,
    UsuarioPublico,
    UsuarioMe,
    LoginResponse,
} from "../types/auth.types.js";
import { AppError } from "../errors/AppError.js";
import { emailService } from "./email.service.js";

// Erro de domínio simples
export class AuthError extends AppError {}

class AuthService {
    register = async ({ nome, email, senha }: RegisterBody): Promise<UsuarioPublico> => {
        const normalizedEmail = email.trim().toLowerCase();
        const userExists = await prisma.usuario.findUnique({
            where: { email: normalizedEmail },
        });

        if (userExists) {
            throw new AuthError("Usuário já existe", 400);
        }

        const senhaHash = await bcrypt.hash(senha, 10);

        const user = await prisma.usuario.create({
            data: { nome, email: normalizedEmail, senha_hash: senhaHash },
        });

        return { id: user.id, nome: user.nome, email: user.email };
    };

    login = async ({ email, senha }: LoginBody): Promise<LoginResponse> => {
        const normalizedEmail = email.trim().toLowerCase();
        const user = await prisma.usuario.findUnique({
            where: { email: normalizedEmail },
        });

        if (!user) throw new AuthError("Usuário não encontrado", 401);

        const senhaValida = await bcrypt.compare(senha, user.senha_hash);

        if (!senhaValida) {
            throw new AuthError("Senha inválida", 401);
        }

        const expiresIn = (process.env.JWT_EXPIRES_IN ?? "1d") as jwt.SignOptions["expiresIn"] & string;

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET as string,
            { expiresIn }
        );

        return {
            token,
            user: { id: user.id, nome: user.nome, email: user.email },
        };
    };

    getMe = async (id: number): Promise<UsuarioMe> => {
        const user = await prisma.usuario.findUnique({ where: { id } });

        if (!user) {
            throw new AuthError("Usuário não encontrado", 404);
        }

        return {
            id: user.id,
            nome: user.nome,
            email: user.email,
            criado_em: user.criado_em,
        };
    };

    updateMe = async (id: number, data: UpdateMeBody): Promise<UsuarioPublico> => {
        const user = await prisma.usuario.update({
            where: { id },
            data,
        });

        return { id: user.id, nome: user.nome, email: user.email };
    };

    updateSenha = async (id: number, { senhaAtual, novaSenha }: UpdateSenhaBody): Promise<void> => {
        const user = await prisma.usuario.findUnique({ where: { id } });

        if (!user) {
            throw new AuthError("Usuário não encontrado.", 404);
        }

        const senhaValida = await bcrypt.compare(senhaAtual, user.senha_hash);

        if (!senhaValida) {
            throw new AuthError("Senha atual incorreta.", 401);
        }

        const novaHash = await bcrypt.hash(novaSenha, 10);

        await prisma.usuario.update({
            where: { id },
            data: { senha_hash: novaHash },
        });
    };

    requestPasswordReset = async ({ email }: ForgotPasswordBody): Promise<void> => {
        if (typeof email !== "string" || !email.trim()) {
            return;
        }

        const normalizedEmail = email.trim().toLowerCase();
        const user = await prisma.usuario.findUnique({
            where: { email: normalizedEmail },
        });

        if (!user) {
            return;
        }

        const token = randomBytes(32).toString("hex");
        const tokenHash = createHash("sha256").update(token).digest("hex");
        const expiraEm = new Date(Date.now() + 30 * 60 * 1000);

        await prisma.$transaction([
            prisma.senhaResetToken.deleteMany({
                where: { usuario_id: user.id },
            }),
            prisma.senhaResetToken.create({
                data: {
                    usuario_id: user.id,
                    token_hash: tokenHash,
                    expira_em: expiraEm,
                },
            }),
        ]);

        try {
            await emailService.sendPasswordReset(user.email, user.nome, token);
        } catch (error) {
            await prisma.senhaResetToken.deleteMany({
                where: { token_hash: tokenHash },
            });

            console.error("Falha no envio do e-mail de redefinição de senha.", error);
        }
    };

    resetPassword = async ({ token, novaSenha }: ResetPasswordBody): Promise<void> => {
        if (
            typeof token !== "string" ||
            !token ||
            typeof novaSenha !== "string" ||
            novaSenha.length < 8
        ) {
            throw new AuthError("Token inválido ou senha com menos de 8 caracteres.", 400);
        }

        const tokenHash = createHash("sha256").update(token).digest("hex");
        const resetToken = await prisma.senhaResetToken.findUnique({
            where: { token_hash: tokenHash },
        });

        if (!resetToken || resetToken.usado_em || resetToken.expira_em <= new Date()) {
            throw new AuthError("Link de redefinição inválido ou expirado.", 400);
        }

        const novaHash = await bcrypt.hash(novaSenha, 10);

        await prisma.$transaction(async (transaction) => {
            const claimedToken = await transaction.senhaResetToken.updateMany({
                where: {
                    id: resetToken.id,
                    usado_em: null,
                    expira_em: { gt: new Date() },
                },
                data: { usado_em: new Date() },
            });

            if (claimedToken.count !== 1) {
                throw new AuthError("Link de redefinição inválido ou expirado.", 400);
            }

            await transaction.usuario.update({
                where: { id: resetToken.usuario_id },
                data: { senha_hash: novaHash },
            });

            await transaction.senhaResetToken.deleteMany({
                where: {
                    usuario_id: resetToken.usuario_id,
                    id: { not: resetToken.id },
                },
            });
        });
    };
}

export const authService = new AuthService();
