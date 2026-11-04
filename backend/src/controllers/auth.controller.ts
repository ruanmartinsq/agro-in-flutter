import { FastifyReply, FastifyRequest } from "fastify";
import { authService, AuthError } from "../service/auth.service.js"
import {
    RegisterBody,
    LoginBody,
    UpdateMeBody,
    UpdateSenhaBody,
    ForgotPasswordBody,
    ResetPasswordBody,
} from "../types/auth.types.js"

class AuthController {

    register = async (request: FastifyRequest<{ Body: RegisterBody }>, reply: FastifyReply) => {
        try {

            const user = await authService.register(request.body);

            return reply.status(201).send(user);
        } catch (error) {

            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao registrar usuário" });
        }
    };

    login = async (request: FastifyRequest<{ Body: LoginBody }>, reply: FastifyReply) => {
        try {
            const result = await authService.login(request.body);

            return reply.send(result);
        } catch (error) {

            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao fazer login" });
        }
    };

    getMe = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const user = await authService.getMe(request.user.id);

            return reply.send(user);
        } catch (error) {

            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao buscar usuário" });
        }
    };

    updateMe = async (request: FastifyRequest<{ Body: UpdateMeBody }>, reply: FastifyReply) => {
        try {
            const user = await authService.updateMe(request.user.id, request.body);

            return reply.send(user);
        } catch (error) {

            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao atualizar usuário" });
        }
    };

    updateSenha = async (request: FastifyRequest<{ Body: UpdateSenhaBody }>, reply: FastifyReply) => {
        try {
            await authService.updateSenha(request.user.id, request.body);

            return reply.send({ message: "Senha alterada com sucesso." });
        } catch (error) {

            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao alterar senha" });
        }
    };

    requestPasswordReset = async (
        request: FastifyRequest<{ Body: ForgotPasswordBody }>,
        reply: FastifyReply,
    ) => {
        await authService.requestPasswordReset(request.body);

        return reply.send({
            message: "Se o e-mail estiver cadastrado, você receberá um link de redefinição.",
        });
    };

    resetPassword = async (
        request: FastifyRequest<{ Body: ResetPasswordBody }>,
        reply: FastifyReply,
    ) => {
        try {
            await authService.resetPassword(request.body);

            return reply.send({ message: "Senha redefinida com sucesso." });
        } catch (error) {
            if (error instanceof AuthError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao redefinir senha" });
        }
    };
}

export const authController = new AuthController();
