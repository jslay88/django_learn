import multiprocessing
import os


wsgi_app = f"{os.getenv('APP_NAME')}.wsgi:application"

workers = multiprocessing.cpu_count() * 2 + 1

bind = "0.0.0.0:8000"

capture_output = False

accesslog = "-"

chdir = os.path.join(os.getenv('APP_HOME', os.path.dirname(__file__)), os.getenv('APP_NAME'))
