#!/bin/bash

# Definimos el criterio de ordenación en una variable
orden_por_defecto="user"  # Usamos "user" para ordenación

# Variables para opciones
incluir_sid_cero=false  # Indica si se debe incluir los procesos con SID 0
usuario_especificado="" # Variable para el nombre de usuario especificado con -u
directorio="" # Variable para el directorio especificado con -d

# Función para mostrar la ayuda
mostrar_ayuda() {
    echo "Uso: infosession.sh [-h] [-z] [-u usuario] [-d directorio]"
    echo
    echo "Opciones:"
    echo "  -h        Muestra esta ayuda y termina."
    echo "  -z        Incluye también los procesos con identificador de sesión 0."
    echo "  -u user   Muestra los procesos del usuario especificado."
    echo "  -d dir    Muestra solo los procesos que tienen archivos abiertos en el directorio dado."
    exit 0
}

# Función para mostrar errores
mostrar_error() {
    echo "Error: $1" >&2
    exit 1
}

# Verificar disponibilidad de herramientas externas
for cmd in ps awk id lsof; do
    if ! command -v $cmd &> /dev/null; then
        mostrar_error "$cmd no está disponible. Por favor, instálalo e inténtalo de nuevo."
    fi
done

# Función para mostrar información de procesos
mostrar_procesos_usuario() {
    local orden="$1" # Parámetro de ordenamiento
    local usuario="${2:-$(whoami)}" # Usa el usuario especificado o el usuario actual si no se define
    local dir="$3"  # Directorio

    # Comprobamos si el usuario existe
    if [[ -n "$usuario" && ! $(id -u "$usuario" 2>/dev/null) ]]; then
        mostrar_error "El usuario '$usuario' no existe."
    fi

    # Imprimimos el encabezado de la tabla
    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"

    # Si se especificó un directorio, utilizamos lsof para obtener PIDs
    if [[ -n "$dir" ]]; then
        # Obtener los PIDs de los procesos que tienen archivos abiertos en el directorio
        pids=$(lsof +D "$dir" | awk 'NR > 1 {print $2}' | sort -u)

        # Comando para obtener la información de los procesos
        ps -eo sid,pgid,pid,user,tty,%mem,cmd --sort="${orden}" | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" -v pids="$pids" '
        BEGIN { split(pids, pid_array) }
        {
            # Incluye el proceso si (a) SID no es 0 o (b) se pasó la opción -z para incluir SID 0
            if ((incluir_sid_cero == "true") || ($1 != "0")) {
                if (user == "" || $4 == user) { # Filtra por el usuario especificado
                    for (pid in pid_array) {
                        if ($3 == pid_array[pid]) { # Compara el PID
                            printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                        }
                    }
                }
            }
        }'
    else
        # Si no hay directorio especificado, mostramos todos los procesos según los demás criterios
        ps -eo sid,pgid,pid,user,tty,%mem,cmd --sort="${orden}" | awk -v user="$usuario" -v incluir_sid_cero="$incluir_sid_cero" '
        {
            if ((incluir_sid_cero == "true") || ($1 != "0")) {
                if (user == "" || $4 == user) {
                    printf "%-10s %-10s %-10s %-10s %-10s %-10s %-s\n", $1, $2, $3, $4, $5, $6, $7
                }
            }
        }'
    fi
}

# Procesar opciones
while getopts ":hzu:d:" opcion; do
    case $opcion in
        h)
            mostrar_ayuda
            ;;
        z)
            incluir_sid_cero=true  # Activa la inclusión de procesos con SID 0
            ;;
        u)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "La opción -u requiere un nombre de usuario."
            fi
            usuario_especificado="$OPTARG"  # Establece el usuario especificado
            ;;
        d)
            if [[ -z "$OPTARG" ]]; then
                mostrar_error "La opción -d requiere un directorio."
            fi
            directorio="$OPTARG"  # Establece el directorio especificado
            ;;
        \?)
            mostrar_error "Opción no válida: -$OPTARG"
            ;;
        :)
            mostrar_error "La opción -$OPTARG requiere un argumento."
            ;;
    esac
done

# Mostrar la tabla de procesos con los parámetros establecidos
mostrar_procesos_usuario "$orden_por_defecto" "$usuario_especificado" "$directorio"
