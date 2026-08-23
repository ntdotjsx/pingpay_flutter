import crypto from "crypto";
import fs from "fs";
import path from "path";

interface ServiceAccountConfig {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export class FcmV1Service {
  private cachedToken: string | null = null;
  private tokenExpiresAt = 0;
  private config: ServiceAccountConfig | null = null;

  constructor() {
    this.loadConfig();
  }

  private loadConfig() {
    // 1. Check direct JSON string in env
    const jsonStr = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (jsonStr) {
      try {
        const parsed = JSON.parse(jsonStr);
        if (parsed.project_id && parsed.client_email && parsed.private_key) {
          this.config = {
            projectId: parsed.project_id,
            clientEmail: parsed.client_email,
            privateKey: parsed.private_key,
          };
          return;
        }
      } catch (err) {
        console.warn("[FCM v1] Failed to parse FIREBASE_SERVICE_ACCOUNT JSON string:", err);
      }
    }

    // 2. Check individual env variables
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;

    if (projectId && clientEmail && privateKeyRaw) {
      this.config = {
        projectId,
        clientEmail,
        privateKey: privateKeyRaw.replace(/\\n/g, "\n"),
      };
      return;
    }

    // 3. Check JSON file path in env or search matching service account files
    const candidatePaths = [
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
      path.resolve(process.cwd(), "pingpay-27b08-firebase-adminsdk-fbsvc-5c96bddd55.json"),
      path.resolve(process.cwd(), "firebase-service-account.json"),
      path.resolve(process.cwd(), "service-account.json"),
    ].filter(Boolean) as string[];

    // Auto-search directory for any firebase-adminsdk json file
    try {
      const files = fs.readdirSync(process.cwd());
      for (const f of files) {
        if (f.endsWith(".json") && (f.includes("firebase-adminsdk") || f.startsWith("pingpay-"))) {
          candidatePaths.unshift(path.resolve(process.cwd(), f));
        }
      }
    } catch (_) {}

    for (const filePath of candidatePaths) {
      if (fs.existsSync(filePath)) {
        try {
          const content = fs.readFileSync(filePath, "utf-8");
          const parsed = JSON.parse(content);
          if (parsed.project_id && parsed.client_email && parsed.private_key) {
            this.config = {
              projectId: parsed.project_id,
              clientEmail: parsed.client_email,
              privateKey: parsed.private_key,
            };
            console.log(`[FCM v1] Loaded Firebase Service Account (${parsed.project_id}) from: ${path.basename(filePath)}`);
            return;
          }
        } catch (err) {
          console.warn(`[FCM v1] Could not load service account from ${filePath}:`, err);
        }
      }
    }
  }

  isConfigured(): boolean {
    if (!this.config) this.loadConfig();
    return this.config !== null;
  }

  getProjectId(): string | null {
    return this.config?.projectId || null;
  }

  /**
   * Generates Google OAuth 2.0 Access Token using RS256 JWT Signed by Service Account
   */
  async getAccessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);

    // Return cached token if valid for at least 5 more minutes
    if (this.cachedToken && this.tokenExpiresAt > now + 300) {
      return this.cachedToken;
    }

    if (!this.config) {
      this.loadConfig();
      if (!this.config) {
        throw new Error(
          "FIREBASE_SERVICE_ACCOUNT_NOT_FOUND: Please provide firebase-service-account.json or FIREBASE_SERVICE_ACCOUNT env var."
        );
      }
    }

    const { clientEmail, privateKey } = this.config;

    // 1. Base64Url Header & Payload
    const header = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url");
    const payload = Buffer.from(
      JSON.stringify({
        iss: clientEmail,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: now + 3600,
        iat: now,
      })
    ).toString("base64url");

    const signInput = `${header}.${payload}`;

    // 2. Sign with Private Key
    const signer = crypto.createSign("RSA-SHA256");
    signer.update(signInput);
    const signature = signer.sign(privateKey, "base64url");

    const signedJwt = `${signInput}.${signature}`;

    // 3. Exchange JWT for Access Token
    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: signedJwt,
      }).toString(),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Google OAuth Token Exchange Failed (${res.status}): ${errText}`);
    }

    const data = (await res.json()) as { access_token: string; expires_in: number };
    this.cachedToken = data.access_token;
    this.tokenExpiresAt = now + data.expires_in;

    return this.cachedToken;
  }

  /**
   * Dispatch Push Notification using Official Google FCM HTTP v1 API
   */
  async sendMessage(params: {
    token: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  }): Promise<{ success: boolean; messageId?: string; error?: string }> {
    try {
      const accessToken = await this.getAccessToken();
      const projectId = this.config!.projectId;

      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

      const payload = {
        message: {
          token: params.token,
          notification: {
            title: params.title,
            body: params.body,
          },
          data: {
            title: params.title,
            body: params.body,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            timestamp: new Date().toISOString(),
            ...(params.data || {}),
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "high_importance_channel",
              sound: "default",
              default_sound: true,
              default_vibrate_timings: true,
              notification_priority: "PRIORITY_HIGH",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const resText = await res.text();

      if (!res.ok) {
        console.error(`[FCM HTTP v1 Error ${res.status}] to ${params.token.slice(0, 15)}...:`, resText);
        return {
          success: false,
          error: `FCM_V1_ERROR (${res.status}): ${resText}`,
        };
      }

      let parsed: any = {};
      try {
        parsed = JSON.parse(resText);
      } catch (_) {}

      console.log(`[FCM HTTP v1 Success] Sent to ${params.token.slice(0, 15)}... MessageId:`, parsed.name);
      return {
        success: true,
        messageId: parsed.name,
      };
    } catch (err: any) {
      console.error("[FCM HTTP v1 Dispatch Exception]:", err.message);
      return {
        success: false,
        error: err.message,
      };
    }
  }
}

export const defaultFcmV1Service = new FcmV1Service();
