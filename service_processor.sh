#!/bin/bash
set -euo pipefail

SERVER=${1:-"default-server"}
DATE=$(date +"%d_%m_%Y")
URL="https://raw.githubusercontent.com/GreatMedivack/files/master/list.out"

FAILED_FILE="${SERVER}_${DATE}_failed.out"
RUNNING_FILE="${SERVER}_${DATE}_running.out"
REPORT_FILE="${SERVER}_${DATE}_report.out"

mkdir -p archives

echo "Начинаем обработку сервисов для сервера: $SERVER"
echo "Дата: $DATE"

echo "Скачиваем файл list.out..."
if ! curl -s -o list.out "$URL"; then
    echo "Ошибка: Не удалось скачать файл list.out"
    exit 1
fi

if [ ! -s list.out ]; then
    echo "Ошибка: Скачанный файл пуст или поврежден"
    exit 1
fi

echo "Файл list.out успешно скачан"

remove_postfix() {
    local name="$1"
    echo "$name" | sed 's/-[a-f0-9]\{10\}-[a-z0-9]\{6\}$//'
}

echo "Обрабатываем сервисы..."

echo "Создаем файл с сервисами с ошибками..."
grep -E "Error|CrashLoopBackOff" list.out | awk '{print $1}' | while read -r service_name; do
    clean_name=$(remove_postfix "$service_name")
    echo "$clean_name" >> "$FAILED_FILE"
done

echo "Создаем файл с работающими сервисами..."
grep "Running" list.out | awk '{print $1}' | while read -r service_name; do
    clean_name=$(remove_postfix "$service_name")
    echo "$clean_name" >> "$RUNNING_FILE"
done

FAILED_COUNT=$(wc -l < "$FAILED_FILE" 2>/dev/null || echo "0")
RUNNING_COUNT=$(wc -l < "$RUNNING_FILE" 2>/dev/null || echo "0")

echo "Создаем файл отчета..."
cat > "$REPORT_FILE" << EOF
Количество работающих сервисов: $RUNNING_COUNT
Количество сервисов с ошибками: $FAILED_COUNT
Имя системного пользователя: $(whoami)
Дата: $(date +"%d/%m/%y")
EOF

chmod 644 "$REPORT_FILE"

echo "Файл отчета создан: $REPORT_FILE"

ARCHIVE_NAME="${SERVER}_${DATE}"
ARCHIVE_PATH="archives/${ARCHIVE_NAME}.tar.gz"

echo "Создаем архив..."

if [ -f "$ARCHIVE_PATH" ]; then
    echo "Архив $ARCHIVE_PATH уже существует, пропускаем создание архива"
else
    tar -czf "$ARCHIVE_PATH" "$FAILED_FILE" "$RUNNING_FILE" "$REPORT_FILE"
    
    if [ $? -eq 0 ]; then
        echo "Архив успешно создан: $ARCHIVE_PATH"
    else
        echo "Ошибка при создании архива"
        exit 1
    fi
fi

echo "Очищаем временные файлы..."
rm -f list.out "$FAILED_FILE" "$RUNNING_FILE" "$REPORT_FILE"

echo "Временные файлы удалены"

echo "Проверяем архив на повреждение..."
if tar -tzf "$ARCHIVE_PATH" >/dev/null 2>&1; then
    echo "✅ Успешно! Архив $ARCHIVE_PATH не поврежден и содержит корректные данные."
    echo "Архив сохранен в папке: archives/"
    echo "Содержимое архива:"
    tar -tzf "$ARCHIVE_PATH"
else
    echo "❌ Ошибка! Архив $ARCHIVE_PATH поврежден или содержит некорректные данные."
    exit 1
fi

echo "Работа скрипта завершена успешно!"
