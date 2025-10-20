#!/bin/bash
# Демонстрационный скрипт для Zygote C Compiler

echo "========================================="
echo "  Zygote C Compiler - Демонстрация"
echo "========================================="
echo ""

# Проверка наличия компилятора
if [ ! -f "./zygote-cc" ]; then
    echo "❌ Компилятор не найден. Запустите 'make' для сборки."
    exit 1
fi

echo "✅ Компилятор найден"
echo ""

# Информация о компиляторе
echo "📊 Информация о компиляторе:"
ls -lh zygote-cc
echo ""

# Статистика проекта
echo "📈 Статистика проекта:"
make stats 2>/dev/null
echo ""

# Примеры программ
echo "📚 Доступные примеры:"
echo ""
for file in examples/*.c; do
    if [ -f "$file" ]; then
        echo "  • $(basename $file)"
        echo "    $(head -1 $file | sed 's|//||')"
    fi
done
echo ""

# Показать содержимое простого примера
echo "📝 Пример программы (examples/simple.c):"
echo "----------------------------------------"
cat examples/simple.c
echo "----------------------------------------"
echo ""

echo "🎓 Обучающие ресурсы:"
echo "  • README.md - Полная документация"
echo "  • QUICKSTART.md - Быстрый старт"
echo "  • docs/architecture.md - Архитектура"
echo "  • docs/design-decisions.md - Дизайн"
echo "  • STATUS.md - Текущий статус"
echo ""

echo "🔧 Полезные команды:"
echo "  make           - Собрать компилятор"
echo "  make clean     - Очистить артефакты"
echo "  make stats     - Показать статистику"
echo "  make help      - Показать справку"
echo ""

echo "✨ Компилятор готов к использованию!"
echo "========================================="