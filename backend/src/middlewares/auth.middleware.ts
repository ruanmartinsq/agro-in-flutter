import { FastifyReply, FastifyRequest } from "fastify";
import jwt, { JwtPayload } from "jsonwebtoken";
import "dotenv/config";

interface TokenPayload extends JwtPayload {
    id: number;
    email: string;
}

export async function authMiddleware(
    request: FastifyRequest,
    reply: FastifyReply
) {
    try {
        const authHeader = request.headers.authorization;

        if (!authHeader) {
            return reply.status(401).send({
                error: "Token não informado."
            });
        }

        const token = authHeader.replace("Bearer ", "");

        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET as string
        );

        if (typeof decoded === "string") {
            return reply.status(401).send({
                error: "Token inválido."
            });
        }

        request.user = {
            id: decoded.id,
            email: decoded.email
        };

    } catch (error) {
        return reply.status(401).send({
            error: "Token inválido ou expirado."
        });
    }
}