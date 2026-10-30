package com.nikoapp;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/**
 * NikoApp 轻量 Java HTTP 服务。
 * 仅使用 JDK 内置 HttpServer，无第三方依赖，便于演示部署与运维链路。
 */
public class App {

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("APP_PORT", "8080"));
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        server.createContext("/", new JsonHandler("hello"));
        server.createContext("/api/health", new JsonHandler("health"));
        server.createContext("/api/hello", new JsonHandler("hello"));

        server.setExecutor(null);
        server.start();
        System.out.println("[NikoApp] started on port " + port);
    }

    static class JsonHandler implements HttpHandler {
        private final String kind;

        JsonHandler(String kind) {
            this.kind = kind;
        }

        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String body;
            if ("health".equals(kind)) {
                body = "{\"status\":\"ok\",\"service\":\"nikoapp\",\"time\":" + System.currentTimeMillis() + "}";
            } else {
                body = "{\"message\":\"hello from nikoapp\",\"backend\":\"internal\"}";
            }
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
            exchange.sendResponseHeaders(200, bytes.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(bytes);
            }
        }
    }
}
