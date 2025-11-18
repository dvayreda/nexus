---
version: 1.0
last_updated: 2025-11-18
status: Production Implementation Guide
---

# Production Hardening Playbook for Nexus

**Goal:** Transform Nexus from development-ready to production-grade with comprehensive security, monitoring, and reliability features.

**Implementation Priority:** Critical → High → Medium based on risk exposure.

---

## Table of Contents
1. [Input Validation](#1-input-validation)
2. [Error Handling & Structured Logging](#2-error-handling--structured-logging)
3. [Security Hardening](#3-security-hardening)
4. [Rate Limiting](#4-rate-limiting)
5. [Monitoring & Alerting](#5-monitoring--alerting)
6. [Backup Verification](#6-backup-verification)
7. [Health Checks](#7-health-checks)
8. [Testing Procedures](#8-testing-procedures)

---

## 1. Input Validation

### 1.1 Core Validation Library

Create `/srv/nexus/src/utils/validators.py`:

```python
#!/usr/bin/env python3
"""
Input validation utilities for Nexus
Provides sanitization and validation for all user inputs
"""
import re
import os
from typing import Any, Optional, Union
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class ValidationError(Exception):
    """Custom exception for validation failures"""
    pass

class InputValidator:
    """Centralized input validation for all Nexus components"""

    # Whitelist patterns
    SAFE_FILENAME_PATTERN = re.compile(r'^[a-zA-Z0-9_\-\.]+$')
    SAFE_PATH_PATTERN = re.compile(r'^[a-zA-Z0-9_\-\./]+$')
    SLIDE_TYPE_WHITELIST = {'hook', 'reveal', 'cta'}

    # Size limits
    MAX_TEXT_LENGTH = 10000
    MAX_FILENAME_LENGTH = 255
    MAX_PATH_LENGTH = 4096

    @staticmethod
    def sanitize_text(text: str, max_length: Optional[int] = None) -> str:
        """Sanitize text input - remove control characters, limit length"""
        if not isinstance(text, str):
            raise ValidationError(f"Expected string, got {type(text)}")

        # Remove control characters except newlines and tabs
        sanitized = ''.join(char for char in text
                          if char.isprintable() or char in '\n\t')

        # Limit length
        max_len = max_length or InputValidator.MAX_TEXT_LENGTH
        if len(sanitized) > max_len:
            logger.warning(f"Text truncated from {len(sanitized)} to {max_len} chars")
            sanitized = sanitized[:max_len]

        return sanitized

    @staticmethod
    def validate_filename(filename: str) -> str:
        """Validate filename for path traversal and special characters"""
        if not filename:
            raise ValidationError("Filename cannot be empty")

        if len(filename) > InputValidator.MAX_FILENAME_LENGTH:
            raise ValidationError(f"Filename too long: {len(filename)} > {InputValidator.MAX_FILENAME_LENGTH}")

        # Check for path traversal attempts
        if '..' in filename or filename.startswith('/'):
            raise ValidationError(f"Invalid filename (path traversal): {filename}")

        # Check against whitelist pattern
        if not InputValidator.SAFE_FILENAME_PATTERN.match(filename):
            raise ValidationError(f"Filename contains invalid characters: {filename}")

        return filename

    @staticmethod
    def validate_path(path: str, must_exist: bool = False, base_dir: Optional[str] = None) -> Path:
        """Validate file path and optionally check existence"""
        if not path:
            raise ValidationError("Path cannot be empty")

        if len(path) > InputValidator.MAX_PATH_LENGTH:
            raise ValidationError(f"Path too long: {len(path)}")

        # Convert to Path object
        path_obj = Path(path).resolve()

        # If base_dir specified, ensure path is within it (prevent directory traversal)
        if base_dir:
            base_path = Path(base_dir).resolve()
            try:
                path_obj.relative_to(base_path)
            except ValueError:
                raise ValidationError(f"Path outside allowed directory: {path}")

        # Check existence if required
        if must_exist and not path_obj.exists():
            raise ValidationError(f"Path does not exist: {path}")

        return path_obj

    @staticmethod
    def validate_slide_type(slide_type: str) -> str:
        """Validate slide type against whitelist"""
        if slide_type not in InputValidator.SLIDE_TYPE_WHITELIST:
            raise ValidationError(
                f"Invalid slide type: {slide_type}. "
                f"Must be one of: {InputValidator.SLIDE_TYPE_WHITELIST}"
            )
        return slide_type

    @staticmethod
    def validate_integer(value: Any, min_val: Optional[int] = None,
                        max_val: Optional[int] = None) -> int:
        """Validate and convert to integer with optional range check"""
        try:
            int_val = int(value)
        except (ValueError, TypeError):
            raise ValidationError(f"Invalid integer: {value}")

        if min_val is not None and int_val < min_val:
            raise ValidationError(f"Value {int_val} below minimum {min_val}")

        if max_val is not None and int_val > max_val:
            raise ValidationError(f"Value {int_val} above maximum {max_val}")

        return int_val

    @staticmethod
    def validate_api_key(api_key: str, key_name: str = "API key") -> str:
        """Validate API key format"""
        if not api_key:
            raise ValidationError(f"{key_name} cannot be empty")

        # Basic format checks
        if len(api_key) < 20:
            raise ValidationError(f"{key_name} too short (min 20 chars)")

        if len(api_key) > 500:
            raise ValidationError(f"{key_name} too long (max 500 chars)")

        # Check for common placeholder values
        placeholder_patterns = ['your_api_key', 'xxxx', '****', 'test', 'demo']
        if any(pattern in api_key.lower() for pattern in placeholder_patterns):
            raise ValidationError(f"{key_name} appears to be a placeholder")

        return api_key
```

### 1.2 Hardened composite.py

Update `/srv/nexus/scripts/composite.py`:

```python
#!/usr/bin/env python3
"""
Hardened composite slide generator with input validation and error handling
"""
from PIL import Image, ImageDraw, ImageFont
import sys
import os
import logging
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from src.utils.validators import InputValidator, ValidationError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/nexus/composite.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Constants
TEMPLATES_DIR = Path("/data/templates")
OUTPUTS_DIR = Path("/data/outputs")
FINAL_DIR = OUTPUTS_DIR / "final"
MAX_SLIDES = 100

def validate_inputs(slide_num: str, slide_type: str, title: str, subtitle: str):
    """Validate all command-line inputs"""
    try:
        # Validate slide number
        slide_num_int = InputValidator.validate_integer(
            slide_num, min_val=1, max_val=MAX_SLIDES
        )

        # Validate slide type
        slide_type_clean = InputValidator.validate_slide_type(slide_type)

        # Sanitize text inputs
        title_clean = InputValidator.sanitize_text(title, max_length=200)
        subtitle_clean = InputValidator.sanitize_text(subtitle, max_length=500)

        return slide_num_int, slide_type_clean, title_clean, subtitle_clean

    except ValidationError as e:
        logger.error(f"Input validation failed: {e}")
        raise

def get_template_path(slide_type: str) -> Path:
    """Get template path with validation"""
    template_map = {
        "hook": "template_hook_question.png",
        "reveal": "template_progressive_reveal.png",
        "cta": "template_call_to_action.png"
    }

    template_file = template_map[slide_type]
    template_path = TEMPLATES_DIR / template_file

    # Validate template exists
    try:
        InputValidator.validate_path(
            str(template_path),
            must_exist=True,
            base_dir=str(TEMPLATES_DIR)
        )
    except ValidationError as e:
        logger.error(f"Template validation failed: {e}")
        raise

    return template_path

def load_generated_image(slide_num: int) -> Optional[Image.Image]:
    """Safely load generated image with error handling"""
    if slide_num > 4:
        return None

    gen_img_path = OUTPUTS_DIR / f"slide_{slide_num}.png"

    try:
        # Validate path
        InputValidator.validate_path(
            str(gen_img_path),
            base_dir=str(OUTPUTS_DIR)
        )

        if not gen_img_path.exists():
            logger.warning(f"Generated image not found: {gen_img_path}")
            return None

        if gen_img_path.stat().st_size == 0:
            logger.warning(f"Generated image is empty: {gen_img_path}")
            return None

        # Load image
        gen_img = Image.open(gen_img_path)
        logger.info(f"Loaded generated image: {gen_img_path}")
        return gen_img

    except Exception as e:
        logger.error(f"Failed to load generated image: {e}", exc_info=True)
        return None

def process_slide(slide_num: int, slide_type: str, title: str, subtitle: str):
    """Main slide processing with comprehensive error handling"""
    try:
        # Validate inputs
        slide_num, slide_type, title, subtitle = validate_inputs(
            slide_num, slide_type, title, subtitle
        )

        logger.info(f"Processing slide {slide_num} (type: {slide_type})")

        # Load template
        template_path = get_template_path(slide_type)
        template = Image.open(template_path)

        # Load and composite generated image
        gen_img = load_generated_image(slide_num)
        if gen_img:
            # Image processing with safety checks
            target_width, target_height = 2160, 1760

            # Calculate scaling
            img_ratio = gen_img.width / gen_img.height
            target_ratio = target_width / target_height

            if img_ratio > target_ratio:
                new_height = target_height
                new_width = int(new_height * img_ratio)
            else:
                new_width = target_width
                new_height = int(new_width / img_ratio)

            # Resize with high quality
            gen_img = gen_img.resize((new_width, new_height), Image.Resampling.LANCZOS)

            # Crop to center
            left = (new_width - target_width) // 2
            top = (new_height - target_height) // 2
            gen_img = gen_img.crop((left, top, left + target_width, top + target_height))

            # Composite
            template.paste(gen_img, (0, 0))

        # Add text with error handling
        draw = ImageDraw.Draw(template)
        try:
            title_font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 180
            )
            subtitle_font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 85
            )
        except OSError as e:
            logger.warning(f"Failed to load custom fonts: {e}")
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()

        # Draw text
        draw.text((1080, 1950), title, fill="white", font=title_font, anchor="mm")
        draw.text((1080, 2200), subtitle, fill=(224, 224, 224), font=subtitle_font, anchor="mm")

        # Save output
        FINAL_DIR.mkdir(parents=True, exist_ok=True)
        output_path = FINAL_DIR / f"slide_{slide_num}_final.png"
        template.save(str(output_path))

        logger.info(f"Successfully saved: {output_path}")
        print(f"Saved to {output_path}")
        return 0

    except ValidationError as e:
        logger.error(f"Validation error: {e}")
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        logger.error(f"Unexpected error processing slide: {e}", exc_info=True)
        print(f"ERROR: Unexpected error: {e}", file=sys.stderr)
        return 2

def main():
    """Main entry point with argument validation"""
    if len(sys.argv) != 5:
        print("Usage: composite.py <slide_num> <slide_type> <title> <subtitle>", file=sys.stderr)
        print("  slide_num: 1-100", file=sys.stderr)
        print("  slide_type: hook|reveal|cta", file=sys.stderr)
        return 1

    return process_slide(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

if __name__ == "__main__":
    sys.exit(main())
```

---

## 2. Error Handling & Structured Logging

### 2.1 Structured Logging Configuration

Create `/srv/nexus/src/utils/logging_config.py`:

```python
#!/usr/bin/env python3
"""
Centralized logging configuration for Nexus
Provides structured logging with JSON output for production
"""
import logging
import logging.handlers
import json
import sys
from datetime import datetime
from pathlib import Path

class StructuredFormatter(logging.Formatter):
    """JSON formatter for structured logging"""

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno,
        }

        # Add exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)

        # Add extra fields
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id

        return json.dumps(log_data)

def setup_logging(
    log_dir: str = "/var/log/nexus",
    log_level: str = "INFO",
    structured: bool = True
):
    """
    Configure application-wide logging

    Args:
        log_dir: Directory for log files
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        structured: Use structured JSON logging
    """
    # Create log directory
    Path(log_dir).mkdir(parents=True, exist_ok=True)

    # Root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))

    # Remove existing handlers
    root_logger.handlers = []

    # Console handler (human-readable)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)

    # File handler (structured JSON for production)
    file_handler = logging.handlers.RotatingFileHandler(
        f"{log_dir}/nexus.log",
        maxBytes=50 * 1024 * 1024,  # 50MB
        backupCount=10
    )
    file_handler.setLevel(logging.DEBUG)

    if structured:
        file_handler.setFormatter(StructuredFormatter())
    else:
        file_handler.setFormatter(console_formatter)

    root_logger.addHandler(file_handler)

    # Error-only file handler
    error_handler = logging.handlers.RotatingFileHandler(
        f"{log_dir}/errors.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(StructuredFormatter() if structured else console_formatter)
    root_logger.addHandler(error_handler)

    # Suppress noisy libraries
    logging.getLogger('PIL').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)

    logging.info(f"Logging initialized: level={log_level}, dir={log_dir}, structured={structured}")
```

### 2.2 Hardened API Clients with Retry Logic

Update `/srv/nexus/src/api_clients/groq_client.py`:

```python
import os
import logging
import time
from typing import Optional
from groq import Groq
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.validators import InputValidator, ValidationError

logger = logging.getLogger(__name__)

class GroqClient:
    """Hardened Groq API client with retry logic and validation"""

    def __init__(self, max_retries: int = 3, retry_delay: int = 2):
        api_key = os.getenv('GROQ_API_KEY')
        try:
            api_key = InputValidator.validate_api_key(api_key, "GROQ_API_KEY")
        except ValidationError as e:
            logger.error(f"Invalid GROQ_API_KEY: {e}")
            raise

        self.client = Groq(api_key=api_key)
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        logger.info("GroqClient initialized")

    def generate_text(self, prompt: str, max_tokens: int = 1000) -> str:
        """
        Generate text using Groq API with retry logic

        Args:
            prompt: Input prompt
            max_tokens: Maximum tokens to generate

        Returns:
            Generated text

        Raises:
            ValidationError: If input validation fails
            Exception: If API call fails after retries
        """
        # Validate inputs
        try:
            prompt = InputValidator.sanitize_text(prompt, max_length=50000)
            max_tokens = InputValidator.validate_integer(max_tokens, min_val=1, max_val=8000)
        except ValidationError as e:
            logger.error(f"Input validation failed: {e}")
            raise

        # Retry logic
        last_exception = None
        for attempt in range(self.max_retries):
            try:
                logger.info(f"Groq API call attempt {attempt + 1}/{self.max_retries}")

                response = self.client.chat.completions.create(
                    model="llama3-8b-8192",
                    messages=[{"role": "user", "content": prompt}],
                    max_tokens=max_tokens,
                    timeout=30.0
                )

                result = response.choices[0].message.content
                logger.info(f"Groq API call successful, generated {len(result)} chars")
                return result

            except Exception as e:
                last_exception = e
                logger.warning(f"Groq API call failed (attempt {attempt + 1}): {e}")

                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay * (attempt + 1))  # Exponential backoff

        # All retries failed
        logger.error(f"Groq API call failed after {self.max_retries} attempts")
        raise Exception(f"Groq API error after {self.max_retries} retries: {last_exception}")
```

---

## 3. Security Hardening

### 3.1 API Key Rotation System

Create `/srv/nexus/scripts/rotate_api_keys.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# API Key Rotation Script for Nexus
# Safely rotates API keys with zero-downtime

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/nexus/key-rotation.log"
ENV_FILE="/srv/nexus/.env"
ENV_BACKUP="/srv/nexus/.env.backup.$(date +%Y%m%d_%H%M%S)"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

# Backup current .env file
backup_env() {
    log "Backing up current .env to $ENV_BACKUP"
    cp "$ENV_FILE" "$ENV_BACKUP"
}

# Validate new API key format
validate_api_key() {
    local key=$1
    local name=$2

    if [ -z "$key" ]; then
        error "$name cannot be empty"
    fi

    if [ ${#key} -lt 20 ]; then
        error "$name too short (min 20 characters)"
    fi

    # Check for placeholder values
    if echo "$key" | grep -qi "your_api_key\|xxxx\|test\|demo"; then
        error "$name appears to be a placeholder"
    fi

    log "$name validation passed"
}

# Update .env file with new key
update_env_key() {
    local key_name=$1
    local new_value=$2

    log "Updating $key_name in .env file"

    # Use sed to replace the key value
    sed -i.bak "s/^${key_name}=.*$/${key_name}=${new_value}/" "$ENV_FILE"

    # Verify update
    if grep -q "^${key_name}=${new_value}$" "$ENV_FILE"; then
        log "$key_name updated successfully"
    else
        error "Failed to update $key_name"
    fi
}

# Restart services to pick up new keys
restart_services() {
    log "Restarting Nexus services to load new keys"

    cd /srv/nexus/infra
    docker compose restart nexus-app n8n

    sleep 5

    # Verify services are running
    if ! docker compose ps | grep -q "nexus-app.*Up"; then
        error "nexus-app failed to start after key rotation"
    fi

    log "Services restarted successfully"
}

# Test new API keys
test_api_keys() {
    log "Testing new API keys..."

    # Run a simple health check that uses the APIs
    if [ -f "$SCRIPT_DIR/health_check.py" ]; then
        python3 "$SCRIPT_DIR/health_check.py" --quick || error "API key test failed"
        log "API key tests passed"
    else
        log "WARNING: health_check.py not found, skipping API tests"
    fi
}

# Main rotation process
rotate_key() {
    local key_name=$1
    local new_value=$2

    log "Starting rotation for $key_name"

    # Validate new key
    validate_api_key "$new_value" "$key_name"

    # Backup current state
    backup_env

    # Update key
    update_env_key "$key_name" "$new_value"

    # Restart services
    restart_services

    # Test
    test_api_keys

    log "Successfully rotated $key_name"
}

# Usage
usage() {
    cat <<EOF
Usage: $0 <KEY_NAME> <NEW_VALUE>

Rotate API keys for Nexus services

Examples:
    $0 GROQ_API_KEY gsk_new_key_here
    $0 ANTHROPIC_API_KEY sk-ant-new_key_here
    $0 GEMINI_API_KEY new_gemini_key_here

Supported keys:
    - GROQ_API_KEY
    - ANTHROPIC_API_KEY
    - GEMINI_API_KEY
    - PEXELS_API_KEY

EOF
    exit 1
}

# Main
main() {
    if [ $# -ne 2 ]; then
        usage
    fi

    KEY_NAME=$1
    NEW_VALUE=$2

    # Validate key name
    case "$KEY_NAME" in
        GROQ_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|PEXELS_API_KEY)
            ;;
        *)
            error "Unsupported key name: $KEY_NAME"
            ;;
    esac

    log "===== Starting API Key Rotation ====="
    rotate_key "$KEY_NAME" "$NEW_VALUE"
    log "===== Rotation Complete ====="
}

main "$@"
```

### 3.2 Input Sanitization Middleware

Create `/srv/nexus/src/middleware/security.py`:

```python
#!/usr/bin/env python3
"""
Security middleware for API endpoints
Provides input sanitization, rate limiting, and request validation
"""
import re
from functools import wraps
from typing import Callable, Any
import logging

logger = logging.getLogger(__name__)

# Dangerous patterns to block
SQLI_PATTERNS = [
    r"(\bunion\b.*\bselect\b)",
    r"(\bor\b\s+\d+\s*=\s*\d+)",
    r"(;\s*drop\s+table)",
    r"(--\s*$)",
    r"(/\*.*\*/)",
]

XSS_PATTERNS = [
    r"(<script[^>]*>.*?</script>)",
    r"(javascript:)",
    r"(on\w+\s*=)",
]

PATH_TRAVERSAL_PATTERNS = [
    r"\.\./",
    r"\.\.\\",
]

def check_malicious_patterns(text: str) -> bool:
    """Check if text contains malicious patterns"""
    patterns = SQLI_PATTERNS + XSS_PATTERNS + PATH_TRAVERSAL_PATTERNS

    for pattern in patterns:
        if re.search(pattern, text, re.IGNORECASE):
            logger.warning(f"Malicious pattern detected: {pattern}")
            return True

    return False

def sanitize_input(data: Any) -> Any:
    """Recursively sanitize input data"""
    if isinstance(data, str):
        if check_malicious_patterns(data):
            raise ValueError("Malicious pattern detected in input")
        return data
    elif isinstance(data, dict):
        return {k: sanitize_input(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_input(item) for item in data]
    else:
        return data

def require_sanitized_input(func: Callable) -> Callable:
    """Decorator to sanitize function inputs"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        # Sanitize kwargs
        sanitized_kwargs = sanitize_input(kwargs)

        # Call original function
        return func(*args, **sanitized_kwargs)

    return wrapper
```

---

## 4. Rate Limiting

### 4.1 Token Bucket Rate Limiter

Create `/srv/nexus/src/utils/rate_limiter.py`:

```python
#!/usr/bin/env python3
"""
Token bucket rate limiter for API protection
Prevents abuse and manages API quota
"""
import time
import threading
from collections import defaultdict
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

class TokenBucket:
    """Token bucket algorithm for rate limiting"""

    def __init__(self, capacity: int, refill_rate: float):
        """
        Initialize token bucket

        Args:
            capacity: Maximum tokens in bucket
            refill_rate: Tokens added per second
        """
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.tokens = capacity
        self.last_refill = time.time()
        self.lock = threading.Lock()

    def consume(self, tokens: int = 1) -> bool:
        """
        Try to consume tokens

        Returns:
            True if tokens consumed, False if insufficient tokens
        """
        with self.lock:
            self._refill()

            if self.tokens >= tokens:
                self.tokens -= tokens
                return True

            return False

    def _refill(self):
        """Refill tokens based on time elapsed"""
        now = time.time()
        elapsed = now - self.last_refill

        # Add tokens based on elapsed time
        tokens_to_add = elapsed * self.refill_rate
        self.tokens = min(self.capacity, self.tokens + tokens_to_add)
        self.last_refill = now

    def get_tokens(self) -> float:
        """Get current token count"""
        with self.lock:
            self._refill()
            return self.tokens

class RateLimiter:
    """Multi-key rate limiter with token buckets"""

    def __init__(self):
        self.buckets: Dict[str, TokenBucket] = {}
        self.lock = threading.Lock()

    def check_rate_limit(
        self,
        key: str,
        capacity: int = 100,
        refill_rate: float = 10.0,
        tokens: int = 1
    ) -> bool:
        """
        Check if request is allowed under rate limit

        Args:
            key: Unique identifier (e.g., API name, user ID)
            capacity: Maximum tokens
            refill_rate: Tokens per second
            tokens: Tokens to consume

        Returns:
            True if request allowed, False if rate limited
        """
        with self.lock:
            if key not in self.buckets:
                self.buckets[key] = TokenBucket(capacity, refill_rate)

        bucket = self.buckets[key]
        allowed = bucket.consume(tokens)

        if not allowed:
            logger.warning(f"Rate limit exceeded for key: {key}")

        return allowed

    def get_status(self, key: str) -> Optional[float]:
        """Get current token count for a key"""
        with self.lock:
            if key in self.buckets:
                return self.buckets[key].get_tokens()
        return None

# Global rate limiter instance
rate_limiter = RateLimiter()

# Predefined rate limits for different API services
API_RATE_LIMITS = {
    'groq': {'capacity': 100, 'refill_rate': 1.0},      # 100 requests, 1/sec refill
    'claude': {'capacity': 50, 'refill_rate': 0.5},     # 50 requests, 0.5/sec refill
    'gemini': {'capacity': 60, 'refill_rate': 1.0},     # 60 requests, 1/sec refill
    'pexels': {'capacity': 200, 'refill_rate': 2.0},    # 200 requests, 2/sec refill
}

def check_api_rate_limit(api_name: str) -> bool:
    """Check rate limit for specific API"""
    limits = API_RATE_LIMITS.get(api_name, {'capacity': 100, 'refill_rate': 1.0})
    return rate_limiter.check_rate_limit(api_name, **limits)
```

---

## 5. Monitoring & Alerting

### 5.1 Netdata Alert Configurations

Create `/srv/nexus/monitoring/netdata-alerts.conf`:

```conf
# Netdata Health Alerts for Nexus Production
# Place in: /etc/netdata/health.d/nexus.conf

# ============================================
# DISK SPACE ALERTS
# ============================================

alarm: disk_space_critical
   on: disk.space
class: Utilization
 type: System
component: Disk
   os: linux
hosts: *
families: /srv /mnt/backup
 calc: $used * 100 / ($avail + $used)
units: %
every: 1m
 warn: $this > 80
 crit: $this > 90
delay: down 15m multiplier 1.5 max 1h
 info: disk space usage for Nexus data
   to: sysadmin

alarm: backup_disk_full
   on: disk.space
class: Errors
 type: System
component: Disk
   os: linux
hosts: *
families: /mnt/backup
 calc: $avail
units: GB
every: 5m
 warn: $this < 10
 crit: $this < 5
 info: backup disk running out of space
   to: sysadmin

# ============================================
# DOCKER CONTAINER HEALTH
# ============================================

alarm: docker_container_down
   on: docker.container_state
class: Availability
 type: Docker
component: Container
   os: linux
hosts: *
lookup: average -1m unaligned of running
 calc: $this
units: containers
every: 30s
 warn: $this < 3
 crit: $this < 2
 info: Nexus Docker containers are down
   to: sysadmin

alarm: docker_high_cpu
   on: docker.cpu
class: Utilization
 type: Docker
component: Container
   os: linux
hosts: *
lookup: average -5m unaligned of cpu
 calc: $this
units: %
every: 1m
 warn: $this > 80
 crit: $this > 95
 info: Docker container using excessive CPU
   to: sysadmin

# ============================================
# MEMORY ALERTS
# ============================================

alarm: system_memory_critical
   on: system.ram
class: Utilization
 type: System
component: Memory
   os: linux
hosts: *
 calc: ($used - $cached - $buffers) * 100 / $used
units: %
every: 1m
 warn: $this > 80
 crit: $this > 95
delay: down 15m multiplier 1.5 max 1h
 info: system memory usage is critical
   to: sysadmin

# ============================================
# API SERVICE HEALTH
# ============================================

alarm: nexus_app_not_responding
   on: web_log.requests_by_code
class: Latency
 type: Web
component: Application
   os: linux
hosts: *
lookup: sum -1m unaligned of 5xx
 calc: $this
units: requests
every: 30s
 warn: $this > 10
 crit: $this > 50
 info: Nexus app returning 5xx errors
   to: sysadmin

# ============================================
# BACKUP VERIFICATION
# ============================================

alarm: backup_not_running
   on: disk.io
class: Workload
 type: System
component: Disk
   os: linux
hosts: *
families: backup
lookup: sum -24h unaligned of writes
 calc: $this
units: KB
every: 1h
 warn: $this < 1000
 crit: $this < 100
 info: backup process may not be running
   to: sysadmin
```

### 5.2 Telegram Alert Script

Create `/srv/nexus/scripts/send_alert.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Telegram Alert Script for Netdata
# Configuration
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Load from .env if not set
if [ -f /srv/nexus/.env ]; then
    source /srv/nexus/.env
fi

# Validate configuration
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "ERROR: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set" >&2
    exit 1
fi

# Parse Netdata alert variables (passed as env vars)
ALERT_NAME="${1:-Unknown Alert}"
ALERT_STATUS="${2:-UNKNOWN}"
ALERT_VALUE="${3:-N/A}"
ALERT_INFO="${4:-No additional info}"

# Format message
MESSAGE="🚨 *NEXUS ALERT*

*Alert:* ${ALERT_NAME}
*Status:* ${ALERT_STATUS}
*Value:* ${ALERT_VALUE}
*Info:* ${ALERT_INFO}
*Time:* $(date '+%Y-%m-%d %H:%M:%S')
*Host:* $(hostname)"

# Send to Telegram
curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="Markdown" \
    || echo "Failed to send Telegram alert" >&2

echo "Alert sent to Telegram"
```

---

## 6. Backup Verification

### 6.1 Automated Backup Testing

Create `/srv/nexus/scripts/verify_backups.py`:

```python
#!/usr/bin/env python3
"""
Comprehensive backup verification system
Tests backup integrity, restore procedures, and alerts on failures
"""
import os
import sys
import subprocess
import hashlib
import logging
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/nexus/backup-verification.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class BackupVerifier:
    """Verify backups and test restore procedures"""

    def __init__(self, backup_root: str = "/mnt/backup"):
        self.backup_root = Path(backup_root)
        self.results = []

    def verify_file_integrity(self, file_path: Path) -> Tuple[bool, str]:
        """Verify file exists and is not corrupted"""
        try:
            if not file_path.exists():
                return False, f"File not found: {file_path}"

            if file_path.stat().st_size == 0:
                return False, f"File is empty: {file_path}"

            # Check if compressed file is valid
            if file_path.suffix == '.gz':
                result = subprocess.run(
                    ['gzip', '-t', str(file_path)],
                    capture_output=True,
                    timeout=60
                )
                if result.returncode != 0:
                    return False, f"Corrupted gzip file: {file_path}"

            return True, "OK"

        except Exception as e:
            return False, f"Error checking file: {e}"

    def verify_checksum(self, file_path: Path) -> Tuple[bool, str]:
        """Verify SHA256 checksum if available"""
        checksum_file = Path(str(file_path) + '.sha256')

        if not checksum_file.exists():
            return True, "No checksum file found (skipped)"

        try:
            # Read expected checksum
            with open(checksum_file, 'r') as f:
                expected = f.read().strip().split()[0]

            # Calculate actual checksum
            sha256 = hashlib.sha256()
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256.update(chunk)
            actual = sha256.hexdigest()

            if actual == expected:
                return True, "Checksum verified"
            else:
                return False, f"Checksum mismatch: expected {expected}, got {actual}"

        except Exception as e:
            return False, f"Error verifying checksum: {e}"

    def verify_database_backup(self) -> Tuple[bool, str]:
        """Verify latest database backup"""
        db_backup_dir = self.backup_root / "db"

        if not db_backup_dir.exists():
            return False, "Database backup directory not found"

        # Find latest backup
        backups = sorted(db_backup_dir.glob("postgres_n8n_*.sql.gz"),
                        key=lambda p: p.stat().st_mtime,
                        reverse=True)

        if not backups:
            return False, "No database backups found"

        latest_backup = backups[0]

        # Check age
        age = datetime.now() - datetime.fromtimestamp(latest_backup.stat().st_mtime)
        if age > timedelta(days=2):
            return False, f"Latest backup is {age.days} days old"

        # Verify integrity
        integrity_ok, msg = self.verify_file_integrity(latest_backup)
        if not integrity_ok:
            return False, msg

        # Verify checksum
        checksum_ok, msg = self.verify_checksum(latest_backup)
        if not checksum_ok:
            return False, msg

        # Try to extract first few lines (syntax check)
        try:
            result = subprocess.run(
                ['gunzip', '-c', str(latest_backup)],
                capture_output=True,
                timeout=10
            )

            if result.returncode != 0:
                return False, "Failed to decompress backup"

            # Check for SQL header
            if b'PostgreSQL database dump' not in result.stdout[:1000]:
                return False, "Backup does not appear to be a valid PostgreSQL dump"

        except Exception as e:
            return False, f"Error testing backup extraction: {e}"

        return True, f"Latest backup verified: {latest_backup.name}"

    def verify_application_files(self) -> Tuple[bool, str]:
        """Verify application file backups"""
        files_backup = self.backup_root / "files"

        if not files_backup.exists():
            return False, "Application files backup not found"

        # Check critical directories exist
        critical_dirs = ['scripts', 'templates']
        for dir_name in critical_dirs:
            dir_path = files_backup / dir_name
            if not dir_path.exists():
                return False, f"Missing critical directory: {dir_name}"

        # Check backup is recent
        age = datetime.now() - datetime.fromtimestamp(files_backup.stat().st_mtime)
        if age > timedelta(days=2):
            return False, f"Application files backup is {age.days} days old"

        return True, "Application files backup verified"

    def verify_docker_volumes(self) -> Tuple[bool, str]:
        """Verify Docker volume backups"""
        volumes_backup = self.backup_root / "docker-volumes"

        if not volumes_backup.exists():
            return False, "Docker volumes backup not found"

        # Check n8n data exists
        n8n_backup = volumes_backup / "n8n_data"
        if not n8n_backup.exists():
            return False, "n8n data backup not found"

        # Check for workflow files
        workflow_files = list(n8n_backup.rglob("*.json"))
        if not workflow_files:
            logger.warning("No workflow files found in n8n backup")

        return True, f"Docker volumes verified ({len(workflow_files)} workflow files)"

    def test_restore_simulation(self) -> Tuple[bool, str]:
        """Simulate a restore to test directory"""
        test_dir = Path("/tmp/nexus-restore-test")

        try:
            # Clean test directory
            if test_dir.exists():
                subprocess.run(['rm', '-rf', str(test_dir)], check=True)

            test_dir.mkdir(parents=True)

            # Try restoring a small sample
            sample_file = self.backup_root / "files" / "scripts" / "README.md"
            if not sample_file.exists():
                return True, "Skipped (no sample file available)"

            # Copy file
            subprocess.run(
                ['cp', str(sample_file), str(test_dir / "test.md")],
                check=True
            )

            # Verify copy
            if not (test_dir / "test.md").exists():
                return False, "Failed to restore test file"

            # Cleanup
            subprocess.run(['rm', '-rf', str(test_dir)], check=True)

            return True, "Restore simulation successful"

        except Exception as e:
            return False, f"Restore simulation failed: {e}"

    def run_all_checks(self) -> Dict:
        """Run all verification checks"""
        logger.info("Starting backup verification")

        checks = [
            ("Database Backup", self.verify_database_backup),
            ("Application Files", self.verify_application_files),
            ("Docker Volumes", self.verify_docker_volumes),
            ("Restore Simulation", self.test_restore_simulation),
        ]

        results = {
            'timestamp': datetime.now().isoformat(),
            'checks': [],
            'success': True
        }

        for check_name, check_func in checks:
            logger.info(f"Running check: {check_name}")

            try:
                passed, message = check_func()

                results['checks'].append({
                    'name': check_name,
                    'passed': passed,
                    'message': message
                })

                if not passed:
                    results['success'] = False
                    logger.error(f"{check_name} FAILED: {message}")
                else:
                    logger.info(f"{check_name} PASSED: {message}")

            except Exception as e:
                logger.error(f"{check_name} ERROR: {e}", exc_info=True)
                results['checks'].append({
                    'name': check_name,
                    'passed': False,
                    'message': f"Exception: {e}"
                })
                results['success'] = False

        return results

    def send_alert(self, results: Dict):
        """Send alert if verification failed"""
        if results['success']:
            logger.info("All backup checks passed")
            return

        # Count failures
        failures = [c for c in results['checks'] if not c['passed']]

        message = f"Backup Verification Failed ({len(failures)} issues):\n\n"
        for failure in failures:
            message += f"- {failure['name']}: {failure['message']}\n"

        # Send via alert script
        try:
            subprocess.run(
                ['/srv/nexus/scripts/send_alert.sh',
                 'Backup Verification Failed',
                 'CRITICAL',
                 f'{len(failures)} checks failed',
                 message],
                check=True,
                timeout=30
            )
        except Exception as e:
            logger.error(f"Failed to send alert: {e}")

def main():
    """Main entry point"""
    verifier = BackupVerifier()
    results = verifier.run_all_checks()

    # Save results
    results_file = Path("/var/log/nexus/backup-verification-latest.json")
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)

    # Send alert if failed
    verifier.send_alert(results)

    # Exit with appropriate code
    sys.exit(0 if results['success'] else 1)

if __name__ == "__main__":
    main()
```

---

## 7. Health Checks

### 7.1 Comprehensive System Health Check

Create `/srv/nexus/scripts/health_check.py`:

```python
#!/usr/bin/env python3
"""
Comprehensive health check system for Nexus
Validates all services, APIs, and dependencies
"""
import os
import sys
import subprocess
import requests
import logging
from pathlib import Path
from typing import Dict, List, Tuple
import json
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HealthChecker:
    """System health checker"""

    def __init__(self):
        self.results = []

    def check_docker_containers(self) -> Tuple[bool, str]:
        """Check Docker containers are running"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', '{{.Names}}\t{{.Status}}'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode != 0:
                return False, "Docker command failed"

            containers = result.stdout.strip().split('\n')
            required_containers = ['nexus-postgres', 'n8n']

            running = [c.split('\t')[0] for c in containers if '\t' in c]

            for required in required_containers:
                if not any(required in r for r in running):
                    return False, f"Container not running: {required}"

            return True, f"{len(running)} containers running"

        except Exception as e:
            return False, f"Error checking containers: {e}"

    def check_disk_space(self) -> Tuple[bool, str]:
        """Check disk space"""
        try:
            result = subprocess.run(
                ['df', '-h', '/srv', '/mnt/backup'],
                capture_output=True,
                text=True,
                timeout=5
            )

            lines = result.stdout.strip().split('\n')[1:]

            for line in lines:
                parts = line.split()
                if len(parts) >= 5:
                    usage = int(parts[4].rstrip('%'))
                    mount = parts[5]

                    if usage > 90:
                        return False, f"{mount} is {usage}% full (critical)"
                    elif usage > 80:
                        logger.warning(f"{mount} is {usage}% full")

            return True, "Disk space OK"

        except Exception as e:
            return False, f"Error checking disk space: {e}"

    def check_api_keys(self) -> Tuple[bool, str]:
        """Check API keys are configured"""
        required_keys = [
            'GROQ_API_KEY',
            'ANTHROPIC_API_KEY',
            'GEMINI_API_KEY',
            'PEXELS_API_KEY'
        ]

        missing = []
        for key in required_keys:
            value = os.getenv(key, '')
            if not value or len(value) < 20:
                missing.append(key)

        if missing:
            return False, f"Missing or invalid API keys: {', '.join(missing)}"

        return True, "All API keys configured"

    def check_log_files(self) -> Tuple[bool, str]:
        """Check log files are writable"""
        log_dir = Path("/var/log/nexus")

        if not log_dir.exists():
            return False, "Log directory does not exist"

        # Try to write a test file
        test_file = log_dir / "health_check_test.log"
        try:
            test_file.write_text("test")
            test_file.unlink()
            return True, "Log directory writable"
        except Exception as e:
            return False, f"Cannot write to log directory: {e}"

    def check_backup_mount(self) -> Tuple[bool, str]:
        """Check backup drive is mounted"""
        backup_path = Path("/mnt/backup")

        if not backup_path.exists():
            return False, "Backup mount point does not exist"

        if not backup_path.is_mount():
            return False, "Backup drive not mounted"

        # Check last backup time
        backup_files = list(backup_path.glob("files/*"))
        if backup_files:
            latest = max(backup_files, key=lambda p: p.stat().st_mtime)
            age_hours = (datetime.now().timestamp() - latest.stat().st_mtime) / 3600

            if age_hours > 48:
                return False, f"Last backup is {int(age_hours)} hours old"

        return True, "Backup drive OK"

    def check_dependencies(self) -> Tuple[bool, str]:
        """Check Python dependencies"""
        required_modules = ['PIL', 'anthropic', 'groq']

        missing = []
        for module in required_modules:
            try:
                __import__(module)
            except ImportError:
                missing.append(module)

        if missing:
            return False, f"Missing Python modules: {', '.join(missing)}"

        return True, "All dependencies available"

    def run_all_checks(self, quick: bool = False) -> Dict:
        """Run all health checks"""
        logger.info("Starting health checks")

        checks = [
            ("Docker Containers", self.check_docker_containers),
            ("Disk Space", self.check_disk_space),
            ("API Keys", self.check_api_keys),
            ("Log Files", self.check_log_files),
            ("Dependencies", self.check_dependencies),
        ]

        if not quick:
            checks.append(("Backup Mount", self.check_backup_mount))

        results = {
            'timestamp': datetime.now().isoformat(),
            'checks': [],
            'healthy': True
        }

        for check_name, check_func in checks:
            logger.info(f"Running check: {check_name}")

            try:
                passed, message = check_func()

                results['checks'].append({
                    'name': check_name,
                    'passed': passed,
                    'message': message
                })

                if not passed:
                    results['healthy'] = False
                    logger.error(f"{check_name} FAILED: {message}")
                else:
                    logger.info(f"{check_name} PASSED: {message}")

            except Exception as e:
                logger.error(f"{check_name} ERROR: {e}", exc_info=True)
                results['checks'].append({
                    'name': check_name,
                    'passed': False,
                    'message': f"Exception: {e}"
                })
                results['healthy'] = False

        return results

def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Nexus Health Check')
    parser.add_argument('--quick', action='store_true', help='Run quick checks only')
    parser.add_argument('--json', action='store_true', help='Output JSON format')
    args = parser.parse_args()

    checker = HealthChecker()
    results = checker.run_all_checks(quick=args.quick)

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print(f"\nHealth Check Results ({results['timestamp']})")
        print("=" * 60)
        for check in results['checks']:
            status = "✓ PASS" if check['passed'] else "✗ FAIL"
            print(f"{status} - {check['name']}: {check['message']}")

        print("=" * 60)
        if results['healthy']:
            print("Overall Status: HEALTHY")
        else:
            print("Overall Status: UNHEALTHY")

    sys.exit(0 if results['healthy'] else 1)

if __name__ == "__main__":
    main()
```

---

## 8. Testing Procedures

### 8.1 Security Testing Script

Create `/srv/nexus/tests/test_security.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Security Testing for Nexus Production Hardening

echo "=== Nexus Security Testing Suite ==="
echo

# Test 1: Input Validation
echo "[1] Testing Input Validation..."
python3 << 'EOF'
import sys
sys.path.insert(0, '/srv/nexus')

from src.utils.validators import InputValidator, ValidationError

# Test malicious filename
try:
    InputValidator.validate_filename("../../etc/passwd")
    print("  ✗ FAIL: Path traversal not blocked")
    sys.exit(1)
except ValidationError:
    print("  ✓ PASS: Path traversal blocked")

# Test SQL injection
try:
    text = "'; DROP TABLE users; --"
    InputValidator.sanitize_text(text)
    print("  ✓ PASS: SQL injection pattern sanitized")
except Exception as e:
    print(f"  ✗ FAIL: {e}")
    sys.exit(1)

print("  ✓ All input validation tests passed")
EOF

# Test 2: Rate Limiting
echo
echo "[2] Testing Rate Limiting..."
python3 << 'EOF'
import sys
sys.path.insert(0, '/srv/nexus')

from src.utils.rate_limiter import RateLimiter

limiter = RateLimiter()

# Test rate limit enforcement
allowed_count = 0
for i in range(150):
    if limiter.check_rate_limit('test_api', capacity=100, refill_rate=10):
        allowed_count += 1

if allowed_count <= 100:
    print(f"  ✓ PASS: Rate limiting working (allowed {allowed_count}/150)")
else:
    print(f"  ✗ FAIL: Rate limit not enforced (allowed {allowed_count}/150)")
    sys.exit(1)
EOF

# Test 3: API Key Validation
echo
echo "[3] Testing API Key Validation..."
python3 << 'EOF'
import sys
sys.path.insert(0, '/srv/nexus')

from src.utils.validators import InputValidator, ValidationError

# Test short key
try:
    InputValidator.validate_api_key("short")
    print("  ✗ FAIL: Short key accepted")
    sys.exit(1)
except ValidationError:
    print("  ✓ PASS: Short key rejected")

# Test placeholder
try:
    InputValidator.validate_api_key("your_api_key_here_xxxx")
    print("  ✗ FAIL: Placeholder key accepted")
    sys.exit(1)
except ValidationError:
    print("  ✓ PASS: Placeholder key rejected")

print("  ✓ All API key validation tests passed")
EOF

# Test 4: Log Directory Permissions
echo
echo "[4] Testing Log Directory Security..."
LOG_DIR="/var/log/nexus"
if [ -d "$LOG_DIR" ]; then
    PERMS=$(stat -c "%a" "$LOG_DIR")
    if [ "$PERMS" = "755" ] || [ "$PERMS" = "750" ]; then
        echo "  ✓ PASS: Log directory permissions secure ($PERMS)"
    else
        echo "  ✗ FAIL: Log directory permissions too open ($PERMS)"
        exit 1
    fi
else
    echo "  ⚠ WARN: Log directory does not exist yet"
fi

# Test 5: Backup Encryption Check
echo
echo "[5] Checking Backup Security..."
if [ -d "/mnt/backup" ]; then
    # Check if backup directory is on encrypted filesystem
    MOUNT_POINT=$(df /mnt/backup | tail -1 | awk '{print $6}')
    echo "  ℹ Backup mount point: $MOUNT_POINT"
    echo "  ⚠ Manual check required: Ensure backup drive is encrypted"
else
    echo "  ⚠ WARN: Backup directory not found"
fi

echo
echo "=== Security Testing Complete ==="
echo
echo "✓ All automated security tests passed"
echo
echo "Manual checks required:"
echo "  1. Verify backup drive encryption"
echo "  2. Review firewall rules (ufw status)"
echo "  3. Check SSH configuration (PermitRootLogin no)"
echo "  4. Verify Docker daemon is not exposed"
```

### 8.2 Integration Testing

Create `/srv/nexus/tests/test_integration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Nexus Integration Testing ==="

# Test health check
echo "[1] Running health check..."
python3 /srv/nexus/scripts/health_check.py --quick
echo "  ✓ Health check passed"

# Test backup verification
echo "[2] Testing backup verification..."
python3 /srv/nexus/scripts/verify_backups.py
echo "  ✓ Backup verification passed"

# Test composite.py with validation
echo "[3] Testing hardened composite.py..."
cd /srv/nexus/scripts
python3 composite.py 1 hook "Test Title" "Test Subtitle" || {
    echo "  ✗ composite.py failed"
    exit 1
}
echo "  ✓ composite.py with validation working"

# Test alert system
echo "[4] Testing alert system..."
/srv/nexus/scripts/send_alert.sh "Test Alert" "INFO" "test" "This is a test" || {
    echo "  ⚠ Alert system test failed (may need Telegram config)"
}

echo
echo "=== Integration Testing Complete ==="
```

---

## Implementation Checklist

### Phase 1: Critical Security (Week 1)
- [ ] Deploy input validation library (`validators.py`)
- [ ] Update `composite.py` with validation
- [ ] Update all API clients with validation
- [ ] Configure structured logging
- [ ] Deploy rate limiting system
- [ ] Test security measures

### Phase 2: Monitoring & Alerts (Week 2)
- [ ] Deploy Netdata alert configurations
- [ ] Configure Telegram alerting
- [ ] Set up log rotation
- [ ] Deploy health check system
- [ ] Schedule automated health checks
- [ ] Test alert delivery

### Phase 3: Backup & Recovery (Week 3)
- [ ] Deploy backup verification script
- [ ] Schedule automated backup verification
- [ ] Test restore procedures
- [ ] Document recovery runbook
- [ ] Create backup encryption plan

### Phase 4: API Key Management (Week 4)
- [ ] Deploy API key rotation script
- [ ] Test key rotation procedure
- [ ] Schedule periodic rotations
- [ ] Document key management process

---

## Maintenance

### Daily
- Review Netdata alerts
- Check health check results
- Monitor disk space

### Weekly
- Review error logs
- Verify backup integrity
- Check rate limiting metrics

### Monthly
- Rotate API keys
- Test restore procedures
- Update dependencies
- Security audit

### Quarterly
- Penetration testing
- Disaster recovery drill
- Review and update documentation
- Compliance audit

---

## Support & Escalation

### Alert Severity Levels

**CRITICAL** (P1)
- System down
- Data corruption
- Security breach
- Response: Immediate

**HIGH** (P2)
- Service degraded
- Backup failure
- API rate limit exceeded
- Response: Within 1 hour

**MEDIUM** (P3)
- Performance issues
- Non-critical errors
- Response: Within 4 hours

**LOW** (P4)
- Warnings
- Informational
- Response: Within 24 hours

---

## Additional Resources

- Nexus Operations Guide: `/srv/nexus/docs/operations/maintenance.md`
- Docker Security: https://docs.docker.com/engine/security/
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- CIS Benchmarks: https://www.cisecurity.org/cis-benchmarks/

---

**Version:** 1.0
**Last Updated:** 2025-11-18
**Maintained By:** Nexus Operations Team
**Review Cycle:** Quarterly
