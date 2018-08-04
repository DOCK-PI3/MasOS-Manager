# -*- coding: utf-8 -*-
"""
Application Crumbs
"""
from autobreadcrumbs import site
from django.utils.translation import ugettext_lazy

site.update({
    'manager:home': ugettext_lazy('Inicio'),
    'manager:bios': ugettext_lazy('Bios'),
	'manager:configes': ugettext_lazy('Configuratión de ES'),
    'manager:config': ugettext_lazy('Configuratión de RetroArch'),
	'manager:configas': ugettext_lazy('Autostart Script'),
    'manager:logs': ugettext_lazy('Logs'),
    'manager:monitoring': ugettext_lazy('Monitorización'),
    'manager:roms-systems': ugettext_lazy('Rom por sistema'),
    'manager:roms-list': ugettext_lazy('{{ system_name }}'),
    #'manager:roms-saves-list': ugettext_lazy('Saves'),
})
