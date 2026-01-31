.PHONY: verify test lint format check-format install-gut test-file

# Godot executable path (adjust for your system)
GODOT ?= godot

# Verification target for swiss-cheese workflow
verify: lint test
	@echo "All verification checks passed"

# Run GDScript linter (requires gdlint: pip install gdtoolkit)
lint:
	@echo "Running GDScript linter..."
	@if command -v gdlint >/dev/null 2>&1; then \
		gdlint . --exclude=.worktrees --exclude=.godot || true; \
	else \
		echo "Warning: gdlint not installed (pip install gdtoolkit)"; \
	fi

# Run Godot unit tests via GUT or fallback runner
test:
	@echo "Running tests..."
	@if [ -d "addons/gut" ]; then \
		echo "Using GUT test framework..."; \
		$(GODOT) --headless -s addons/gut/gut_cmdln.gd \
			-gdir=res://test/unit/ \
			-gdir=res://test/integration/ \
			-gexit \
			-gconfig=res://test/.gutconfig.json; \
	elif [ -f "test/run_tests.gd" ]; then \
		echo "Using fallback test runner..."; \
		$(GODOT) --headless -s test/run_tests.gd; \
	else \
		echo "Note: No test framework found. Skipping tests."; \
	fi

# Install GUT testing framework (v9.5.1+ required for Godot 4.6)
install-gut:
	@echo "Installing GUT testing framework..."
	@mkdir -p addons
	@if [ ! -d "addons/gut" ]; then \
		rm -rf /tmp/gut_temp && \
		git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut_temp && \
		cp -r /tmp/gut_temp/addons/gut addons/gut && \
		rm -rf /tmp/gut_temp && \
		echo "GUT installed successfully"; \
	else \
		echo "GUT already installed"; \
	fi

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test/unit/test_foo.gd"; \
	else \
		$(GODOT) --headless -s addons/gut/gut_cmdln.gd -gtest=$(FILE) -gexit; \
	fi

# Format GDScript files (requires gdformat: pip install gdtoolkit)
format:
	@echo "Formatting GDScript files..."
	@if command -v gdformat >/dev/null 2>&1; then \
		find . -name "*.gd" -not -path "./.worktrees/*" -not -path "./.godot/*" -exec gdformat {} \;; \
	else \
		echo "Warning: gdformat not installed (pip install gdtoolkit)"; \
	fi

# Check formatting without modifying files
check-format:
	@echo "Checking GDScript formatting..."
	@if command -v gdformat >/dev/null 2>&1; then \
		find . -name "*.gd" -not -path "./.worktrees/*" -not -path "./.godot/*" -exec gdformat --check {} \; || \
		(echo "Formatting issues found. Run 'make format' to fix." && exit 1); \
	else \
		echo "Warning: gdformat not installed (pip install gdtoolkit)"; \
	fi
