<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    /**
     * Handle an incoming request and attach Zero-Trust Military-Grade Security Headers.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // 1. Anti-Null-Byte & Input Sanitization
        foreach ($request->all() as $key => $val) {
            if (is_string($val) && str_contains($val, "\0")) {
                abort(400, 'Karakter ilegal terdeteksi (Null-byte injection attempt).');
            }
        }

        $response = $next($request);

        // 2. Strip Server Fingerprinting Headers (Reconnaissance Defense)
        if (function_exists('header_remove')) {
            @header_remove('X-Powered-By');
            @header_remove('Server');
        }
        $response->headers->remove('X-Powered-By');
        $response->headers->remove('Server');

        // 3. Attach Zero-Trust Security Headers
        $response->headers->set('X-Frame-Options', 'SAMEORIGIN');
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
        $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');

        return $response;
    }
}
