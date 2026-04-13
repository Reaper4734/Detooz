import sys
import test_tflite_automated

class Tee(object):
    def __init__(self, name, mode):
        self.file = open(name, mode, encoding='utf-8')
        self.stdout = sys.stdout
    def write(self, data):
        try:
            self.file.write(data)
            self.stdout.write(data)
        except Exception:
            pass # Ignore encoding errors
    def flush(self):
        try:
            self.file.flush()
            self.stdout.flush()
        except Exception:
            pass
    def close(self):
        self.file.close()

if __name__ == '__main__':
    # Force UTF-8 for stdout if possible
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass
        
    original = sys.stdout
    tee = Tee('model_results.txt', 'w')
    sys.stdout = tee
    try:
        test_tflite_automated.run_automated_test()
    finally:
        sys.stdout = original
        tee.close()
