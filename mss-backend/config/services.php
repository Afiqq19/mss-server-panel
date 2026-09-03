<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Portainer Local API Configuration (Bab 1, 2, 4)
    |--------------------------------------------------------------------------
    */
    'portainer' => [
        'url' => env('PORTAINER_URL', 'http://127.0.0.1:9000'),
        'api_key' => env('PORTAINER_API_KEY'),
        'endpoint_id' => env('PORTAINER_ENVIRONMENT_ID', env('PORTAINER_ENDPOINT_ID', 1)),
    ],

    /*
    |--------------------------------------------------------------------------
    | VPS Host Metrics & Hardware Monitoring (Bab 4, 9.A)
    |--------------------------------------------------------------------------
    */
    'server_monitor' => [
        'proc_path' => env('HOST_PROC_PATH', '/proc'),
        'sys_path' => env('HOST_SYS_PATH', '/sys'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Nextcloud NAS Backup Module (Bab 9.B)
    |--------------------------------------------------------------------------
    */
    'backup' => [
        'storage_path' => env('NEXTCLOUD_BACKUP_PATH', '/var/lib/docker/volumes/nas-mss_nextcloud_data/_data/data/mss/files/Backup-Server/'),
        'script_path' => env('BACKUP_SCRIPT_PATH', '/home/mss/backup-otomatis/jalankan-backup.sh'),
    ],

];
