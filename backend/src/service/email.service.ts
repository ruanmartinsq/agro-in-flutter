import { Resend } from "resend";

const escapeHtml = (value: string) =>
    value.replace(
        /[&<>"']/g,
        (character) =>
            ({
                "&": "&amp;",
                "<": "&lt;",
                ">": "&gt;",
                '"': "&quot;",
                "'": "&#039;",
            })[character] as string,
    );

class EmailService {
    private getClient() {
        const apiKey = process.env.RESEND_API_KEY;

        if (!apiKey) {
            throw new Error("RESEND_API_KEY não configurada.");
        }

        return new Resend(apiKey);
    }

    async sendPasswordReset(to: string, nome: string, token: string) {
        const frontendUrl = process.env.FRONTEND_URL ?? "https://agro-in.vercel.app";
        const resetUrl = new URL("/redefinir-senha", frontendUrl);
        resetUrl.searchParams.set("token", token);

        const from = process.env.RESEND_FROM_EMAIL ?? "Agro.in <onboarding@resend.dev>";
        const safeName = escapeHtml(nome.normalize("NFC"));
        const safeResetUrl = escapeHtml(resetUrl.toString());

        const { error } = await this.getClient().emails.send({
            from,
            to,
            subject: "Redefini\u00e7\u00e3o de senha - Agro.in",
            html: `<!doctype html>
                <html lang="pt-BR">
                    <head>
                        <meta charset="UTF-8">
                        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1.0">
                        <title>Redefini&ccedil;&atilde;o de senha - Agro.in</title>
                    </head>
                    <body style="margin:0;background:#f5f7f4;padding:0;font-family:Arial,sans-serif;color:#172015">
                        <div style="margin:0;background:#f5f7f4;padding:40px 16px">
                            <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;padding:32px;border:1px solid #e5eadf">
                                <p style="margin:0 0 12px;color:#0d5006;font-weight:700;font-size:14px;letter-spacing:.08em">AGRO.IN</p>
                                <h1 style="margin:0 0 16px;font-size:26px;line-height:1.25">Redefina sua senha</h1>
                                <p style="margin:0 0 16px;line-height:1.6">Ol&aacute;, ${safeName}.</p>
                                <p style="margin:0 0 24px;line-height:1.6">
                                    Recebemos uma solicita&ccedil;&atilde;o para redefinir a senha da sua conta.
                                    O link abaixo &eacute; v&aacute;lido por 30 minutos e pode ser usado uma &uacute;nica vez.
                                </p>
                                <a href="${safeResetUrl}" style="display:inline-block;background:#0d5006;color:#ffffff;text-decoration:none;padding:14px 22px;border-radius:10px;font-weight:700">
                                    Redefinir minha senha
                                </a>
                                <p style="margin:24px 0 8px;font-size:13px;line-height:1.5;color:#647060">
                                    Se o bot&atilde;o n&atilde;o funcionar, copie e cole este endere&ccedil;o no navegador:
                                </p>
                                <p style="margin:0;word-break:break-all;font-size:12px;color:#0d5006">${safeResetUrl}</p>
                                <p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#647060">
                                    Se voc&ecirc; n&atilde;o solicitou esta altera&ccedil;&atilde;o, ignore este e-mail.
                                </p>
                            </div>
                        </div>
                    </body>
                </html>`,
            text: `Ol\u00e1, ${nome.normalize("NFC")}. Redefina sua senha do Agro.in em: ${resetUrl.toString()} O link \u00e9 v\u00e1lido por 30 minutos.`,
        });

        if (error) {
            throw new Error(`Falha ao enviar e-mail de redefinição: ${error.message}`);
        }
    }
}

export const emailService = new EmailService();
