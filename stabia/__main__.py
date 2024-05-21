if __name__ == '__main__':
  import sys, importlib
  if len(sys.argv) <= 1:
    print("Usage: python -m stabia COMMAND [ARGS...]")
    exit(1)
  _, command, *args = sys.argv
  module = importlib.import_module(f"stabia.{command}")
  module.main(*args)
