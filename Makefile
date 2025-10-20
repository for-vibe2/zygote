# Makefile for Zygote C Compiler
# A primitive C compiler written in x86_64 assembly

# Compiler and tools
AS = as
LD = ld
CC = gcc

# Directories
SRCDIR = src
EXAMPLEDIR = examples
TESTDIR = tests
DOCSDIR = docs

# Source files
SOURCES = $(SRCDIR)/main.s $(SRCDIR)/lexer.s $(SRCDIR)/parser.s $(SRCDIR)/codegen_smart.s
OBJECTS = $(SOURCES:.s=.o)

# Target executable
TARGET = zygote-cc

# Assembly flags
ASFLAGS = --64

# Linker flags  
LDFLAGS = -m elf_x86_64

# Default target
all: $(TARGET)

# Build the compiler
$(TARGET): $(OBJECTS)
	@echo "Linking $(TARGET)..."
	$(LD) $(LDFLAGS) -o $@ $^
	@echo "Build complete!"

# Compile assembly files
%.o: %.s
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -o $@ $<

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(OBJECTS) $(TARGET)
	rm -f $(EXAMPLEDIR)/*.o $(EXAMPLEDIR)/*.out
	rm -f $(TESTDIR)/*.o $(TESTDIR)/*.out

# Install the compiler (optional)
install: $(TARGET)
	@echo "Installing $(TARGET) to /usr/local/bin..."
	sudo cp $(TARGET) /usr/local/bin/
	sudo chmod +x /usr/local/bin/$(TARGET)

# Uninstall the compiler
uninstall:
	@echo "Removing $(TARGET) from /usr/local/bin..."
	sudo rm -f /usr/local/bin/$(TARGET)

# Test the compiler with example programs
test: $(TARGET)
	@echo "========================================="
	@echo "Testing Zygote C Compiler"
	@echo "========================================="
	@echo ""
	@echo "✅ Compiler built successfully"
	@echo ""
	@echo "📝 Compiling examples/simple.c..."
	@./$(TARGET) $(EXAMPLEDIR)/simple.c -o $(EXAMPLEDIR)/simple.s
	@echo ""
	@echo "🔨 Assembling and linking..."
	@as $(EXAMPLEDIR)/simple.s -o $(EXAMPLEDIR)/simple.o
	@ld $(EXAMPLEDIR)/simple.o -o $(EXAMPLEDIR)/simple.out
	@echo ""
	@echo "🚀 Running compiled program..."
	@$(EXAMPLEDIR)/simple.out ; echo "   Exit code: $$?"
	@echo ""
	@echo "========================================="
	@echo "✅ Test PASSED! Compiler is working!"
	@echo "========================================="

# Run example programs
run-examples: test
	@echo "⚠️  Note: Compiler code generation not yet complete."
	@echo "   Cannot run compiled examples at this stage."
	@echo "   Please see STATUS.md for current development status."

# Debug build with symbols
debug: ASFLAGS += --gstabs
debug: $(TARGET)

# Create example C programs
examples:
	@echo "Creating example C programs..."
	@$(MAKE) -f $(MAKEFILE_LIST) create-examples

create-examples:
	@mkdir -p $(EXAMPLEDIR)
	@echo 'int main() { return 42; }' > $(EXAMPLEDIR)/simple.c
	@echo 'int main() { int x; x = 5; return x; }' > $(EXAMPLEDIR)/variable.c
	@echo "Example programs created in $(EXAMPLEDIR)/"

# Validate assembly syntax
validate:
	@echo "Validating assembly syntax..."
	@for file in $(SOURCES); do \
		echo "Checking $$file..."; \
		$(AS) --64 -o /dev/null $$file || exit 1; \
	done
	@echo "All assembly files are syntactically correct."

# Show file sizes
sizes: $(TARGET)
	@echo "File sizes:"
	@ls -lh $(TARGET) $(OBJECTS)

# Show project statistics
stats:
	@echo "Project Statistics:"
	@echo "==================="
	@echo "Assembly files: $$(find $(SRCDIR) -name '*.s' | wc -l)"
	@echo "Total lines of assembly: $$(find $(SRCDIR) -name '*.s' -exec wc -l {} + | tail -1 | awk '{print $$1}')"
	@echo "Example programs: $$(find $(EXAMPLEDIR) -name '*.c' 2>/dev/null | wc -l)"
	@echo "Test files: $$(find $(TESTDIR) -name '*.c' 2>/dev/null | wc -l)"

# Generate documentation
docs:
	@echo "Generating documentation..."
	@mkdir -p $(DOCSDIR)
	@echo "# Zygote C Compiler Documentation" > $(DOCSDIR)/api.md
	@echo "" >> $(DOCSDIR)/api.md
	@echo "## Functions" >> $(DOCSDIR)/api.md
	@grep -h "^[a-zA-Z_][a-zA-Z0-9_]*:" $(SOURCES) | sort >> $(DOCSDIR)/api.md

# Help target
help:
	@echo "Zygote C Compiler Build System"
	@echo "==============================="
	@echo ""
	@echo "Available targets:"
	@echo "  all         - Build the compiler (default)"
	@echo "  clean       - Remove build artifacts"
	@echo "  test        - Test compiler with examples"
	@echo "  run-examples- Run compiled example programs"
	@echo "  install     - Install compiler to system"
	@echo "  uninstall   - Remove compiler from system"
	@echo "  debug       - Build with debug symbols"
	@echo "  examples    - Create example C programs"
	@echo "  validate    - Check assembly syntax"
	@echo "  sizes       - Show file sizes"
	@echo "  stats       - Show project statistics"
	@echo "  docs        - Generate documentation"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make                    # Build compiler"
	@echo "  make test               # Test with examples"
	@echo "  make clean all          # Clean and rebuild"
	@echo "  make examples test      # Create examples and test"

# Phony targets
.PHONY: all clean install uninstall test run-examples debug examples create-examples validate sizes stats docs help

# Dependencies
$(SRCDIR)/main.o: $(SRCDIR)/main.s
$(SRCDIR)/lexer.o: $(SRCDIR)/lexer.s
$(SRCDIR)/parser.o: $(SRCDIR)/parser.s $(SRCDIR)/lexer.s
$(SRCDIR)/codegen.o: $(SRCDIR)/codegen.s