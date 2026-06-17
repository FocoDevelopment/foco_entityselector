fx_version 'cerulean'
game 'gta5'

author 'Lime Studios'
description 'Admin Entity Inspector'
version '2.3.1'

-- Set to true in your server.cfg via:  setr lime_entityselector_suppressUpdates true
-- or per-resource:  suppress_updates 'true'  (read by _versioncheck.lua)

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    '_versioncheck.lua',
}

ui_page 'html/dist/index.html'

files {
    'html/dist/index.html',
    'html/dist/assets/*.js',
    'html/dist/assets/*.css',
}

lua54 'yes'
