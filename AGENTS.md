# Repository Guidelines

## Project Structure & Module Organization
- `app/`: Flask application code.
- `app/app.py`: Web entrypoint and routes.
- `app/option_calculator.py`: Options pricing/return calculations.
- `app/templates/`: Jinja2 templates (`index.html`).
- `app/static/`: Static assets (CSS).
- `terraform/`: Infrastructure as code for AWS (ECS/ALB/ACM/Route 53).
- `README.md`: High-level architecture and deployment steps.

## Build, Test, and Development Commands
- `cd app && uv run python app.py`: Run the Flask app locally with uv (listens on `0.0.0.0:5001`).
- `cd app && uv lock`: Generate or update the uv.lock file after changing dependencies.
- `cd app && uv add <package>`: Add a new Python dependency.
- `docker build -t options-app:latest ./app`: Build the app image locally (uses Python 3.14 + uv base image).
- `docker run -p 5001:5000 options-app:latest`: Run the container locally.
- `terraform -chdir=terraform init`: Initialize Terraform providers.
- `terraform -chdir=terraform apply`: Apply infrastructure changes.
- `aws ecs update-service --cluster options-app-cluster --service options-app-service --force-new-deployment --region us-east-1`: Force ECS to pull and deploy latest Docker image.

## Coding Style & Naming Conventions
- Python: follow the existing style in `app/app.py` and `app/option_calculator.py`.
- Indentation: 4 spaces.
- Naming: `snake_case` for functions/variables, `CamelCase` for classes.
- Templates/CSS: keep class names readable and consistent with current usage.
- Dependencies: use `uv add` to manage dependencies (don't manually edit pyproject.toml for dependencies).
- Type hints: use type hints in function signatures (see option_calculator.py for examples).

## Testing Guidelines
- There is no test suite in this repository yet.
- If you add tests, document the framework and include a one-line run command in this file.
- Prefer naming tests `test_*.py` and placing them under `app/tests/` or `tests/`.

## Commit & Pull Request Guidelines
- Commit messages in history are short and descriptive (e.g., “fixing deprecated code”).
- Keep commits focused and summarize the primary change in the subject line.
- Pull requests should include a short summary of the change and why it’s needed.
- Pull requests should link relevant issues or context.
- Pull requests should include screenshots for UI changes (template/CSS updates).
- Pull requests should note any Terraform changes and required apply steps.

## Application Features
- **Dynamic Return Filter**: Users can configure the annualized return threshold (default 15%) via a number input field. This value is passed from the frontend template to the backend and used in filtering.
- **Responsive Pivot Tables**: Tables use full viewport width with horizontal scrolling when needed. CSS includes media queries for mobile devices.
- **Real-time Price Data**: Uses yfinance with curl_cffi session impersonation to bypass rate limiting.

## Security & Configuration Tips
- Do not commit secrets. Replace `app.secret_key` with an environment-sourced value for production.
- When changing AWS infrastructure, verify region/account assumptions before `terraform apply`.
- Port 5000 on macOS is often used by AirPlay/ControlCenter, so local development uses port 5001.
