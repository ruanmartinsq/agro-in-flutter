import { JwtPayload } from "jsonwebtoken";

export interface TokenPayload extends JwtPayload {
    id: number;
    email: string;
}

export interface RegisterBody {
    nome: string;
    email: string;
    senha: string;
}

export interface LoginBody {
    email: string;
    senha: string;
}

export interface UpdateMeBody {
    nome?: string;
    email?: string;
}

export interface UpdateSenhaBody {
    senhaAtual: string;
    novaSenha: string;
}

export interface ForgotPasswordBody {
    email: string;
}

export interface ResetPasswordBody {
    token: string;
    novaSenha: string;
}

export interface UsuarioPublico {
    id: number;
    nome: string;
    email: string;
}

export interface UsuarioMe extends UsuarioPublico {
    criado_em: Date;
}

export interface LoginResponse {
    token: string;
    user: UsuarioPublico;
}
