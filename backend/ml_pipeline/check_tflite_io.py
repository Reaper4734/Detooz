import tensorflow as tf

interpreter = tf.lite.Interpreter('backend/ml_pipeline/data/en_hinglish/scam_detector.tflite')
interpreter.allocate_tensors()

print('Input Details:')
for inp in interpreter.get_input_details():
    print(f'  Name: {inp["name"]}')
    print(f'  Shape: {inp["shape"]}')
    print(f'  Dtype: {inp["dtype"]}')
    print()

print('Output Details:')
for out in interpreter.get_output_details():
    print(f'  Name: {out["name"]}')
    print(f'  Shape: {out["shape"]}')
    print(f'  Dtype: {out["dtype"]}')
