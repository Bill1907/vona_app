// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// @ts-ignore: Deno 모듈 사용
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
// @ts-ignore: Deno 모듈 사용
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// @ts-ignore: JWT 생성 라이브러리
import { create, verify } from "https://deno.land/x/djwt@v2.8/mod.ts";

// Deno 타입 선언
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

interface NotificationPayload {
  userId?: string;
  topic?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req) => {
  try {
    // CORS 헤더
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST",
          "Access-Control-Allow-Headers":
            "authorization, x-client-info, apikey, content-type",
        },
      });
    }

    // 요청 본문 파싱
    const payload: NotificationPayload = await req.json();

    // 기본 검증
    if (!payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: "Title and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 타겟 확인 (userId 또는 topic)
    if (!payload.userId && !payload.topic) {
      return new Response(
        JSON.stringify({ error: "Either userId or topic is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Supabase 클라이언트 초기화
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let fcmTokens: string[] = [];

    // userId로 FCM 토큰 조회
    if (payload.userId) {
      const { data, error } = await supabaseAdmin
        .from("fcm_tokens")
        .select("token")
        .eq("user_id", payload.userId)
        .single();

      if (error) {
        console.error("Error fetching FCM token:", error);
        return new Response(
          JSON.stringify({ error: "Failed to fetch FCM token" }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }

      if (data?.token) {
        fcmTokens.push(data.token);
      }
    }

    // 서비스 계정 키 JSON 문자열 가져오기
    const serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountStr) {
      return new Response(
        JSON.stringify({ error: "Firebase service account not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // 서비스 계정 JSON 파싱
    const serviceAccount = JSON.parse(serviceAccountStr);

    // JWT 토큰 생성
    const now = Math.floor(Date.now() / 1000);
    const jwtToken = await create(
      { alg: "RS256", typ: "JWT" },
      {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: "https://fcm.googleapis.com/",
        iat: now,
        exp: now + 3600, // 1시간 유효
      },
      serviceAccount.private_key
    );

    // FCM HTTP v1 API 호출 준비
    const projectId = serviceAccount.project_id;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    // FCM 메시지 구성
    let fcmMessage;

    if (payload.topic) {
      // 토픽 메시지
      fcmMessage = {
        message: {
          topic: payload.topic,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data || {},
        },
      };
    } else if (fcmTokens.length > 0) {
      // 단일 토큰 메시지
      fcmMessage = {
        message: {
          token: fcmTokens[0],
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data || {},
        },
      };
    } else {
      return new Response(
        JSON.stringify({ error: "No valid FCM tokens found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // FCM API 호출
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${jwtToken}`,
      },
      body: JSON.stringify(fcmMessage),
    });

    // FCM 응답 처리
    const fcmResponse = await response.json();

    if (!response.ok) {
      console.error("FCM error:", fcmResponse);
      return new Response(
        JSON.stringify({ error: "FCM request failed", details: fcmResponse }),
        {
          status: response.status,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify({ success: true, fcmResponse }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Unexpected error:", error);

    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
