import math
import numpy as np
import cv2
import serial
import time
import os
import sys
import random

if len(sys.argv) < 2:
	print("Usage: python run.sh [tranining/modeldown/inference] [modelfile]")
	exit()

option = sys.argv[1]

if option == "modeldown" or option=="inference":
	if len(sys.argv) < 3:
		print("need serial port name")
		exit()
	serial_name = sys.argv[2]

if option == "training":
	import csv
	import copy
	
	print("Reading training file...")
	training_data_csv = open('data/mnist_train.csv')
	training_data_csv_reader = csv.reader(training_data_csv, delimiter=',')
	training_data=[]
	training_label=[]
	for row in training_data_csv_reader:
		training_label.append(row[0])
		training_data.append(row[1:])
	training_data = np.array(training_data, dtype='float32').reshape((-1,28,28))
	
	print("Reading test file...")
	test_data_csv = open('data/mnist_test.csv')
	test_data_csv_reader = csv.reader(test_data_csv, delimiter=',')
	test_data=[]
	test_label=[]
	for row in test_data_csv_reader:
		test_label.append(row[0])
		test_data.append(row[1:])
	test_data = np.array(test_data, dtype='float32').reshape((-1, 28, 28))
	
	# MODEL / HYPER_PARAMETER SPECIFICATION
	batch_size = 50
	iteration = 20
	learning_rate = 0.001
	model = [
		[784, 8],
		[8, 48],
		[48, 8],
		[8, 48],
		[48, 8],
		[8, 10]
	]
	n_layer = len(model)
	
	# Xavier Weight Initialization
	weights = [ np.random.randn(model[i][0], model[i][1]).astype('float32')*math.sqrt(1 / (model[i][0]+model[i][1])) for i in range(len(model)) ]
	
	# Image Preprocess
	training_data = ((training_data - 128.0) / 128.0)
	test_data = ((test_data - 128.0) / 128.0)

	for iter in range(iteration):
		print("Iteration%2d" % iter, ": ", end='', flush=True)
		
		randset = [i for i in range(len(training_label))]
		
		#Training
		for batch in range(int(len(training_label)/batch_size)):
			if batch % int(len(training_label)/batch_size/10) == 0:
				print(".", end='', flush=True)

			sample_num = random.sample(randset, batch_size)
			
			tensors=[]
			tensor = np.array([training_data[i].reshape((-1)) for i in sample_num], dtype='float32')
			tensors.append(tensor.copy())
			
			#forward
			for layer in range(n_layer):
				tensor = np.dot(tensor, weights[layer])
				if(layer<n_layer-1):
					tensor = np.clip(tensor, 0, np.max(tensor))
				else:
					tensor = np.exp(tensor)
					sum = np.sum(tensor, axis=1).reshape((-1, 1))
					tensor = np.divide(tensor,sum)
				tensors.append(tensor.copy())
			#backward
			gradients = []
			for i in range(batch_size):
				tensor[i][int(training_label[sample_num[i]])] -= 1
			gradients.append(tensor.copy())
			for layer in range(n_layer-1, -1, -1):
				tensor=np.dot(tensor, weights[layer].T)
				zeroidx = np.where(tensors[layer] == 0)
				tensor[zeroidx] = 0
				gradients.append(tensor.copy())
			#Update
			for layer in range(n_layer):
				weight_error = np.dot(tensors[layer].T, gradients[n_layer-layer-1])
				weights[layer] = weights[layer] - learning_rate * weight_error
				
		#Validation
		correct = 0
		error = 0
		for i in range(len(test_label)):
			tensor = np.array([test_data[i].reshape((-1))], dtype='float32')
			
			#forward
			for layer in range(n_layer):
				tensor = np.dot(tensor, weights[layer])
				if(layer<n_layer-1):
					tensor = np.clip(tensor, 0, np.max(tensor))
			answer = np.argmax(tensor)
			if int(answer) == int(test_label[i]):
				correct += 1
			else:
				error += 1
		print("\tValidation Accuracy: %0.2f %%" % (correct/(error+correct)*100), end='')
				
		#Qunatized Model Validation
		correct = 0
		error = 0
		quantized_weights = copy.deepcopy(weights)
		layer_shift = []
		#Quantize Weight
		for i in range(len(quantized_weights)):
			shift = 127 / np.max(np.abs(quantized_weights[i]))
			shift = int(math.pow(2, int(math.log(shift, 2))))
			quantized_weights[i] *= shift
			quantized_weights[i] = np.clip(quantized_weights[i], -128, 127)
			quantized_weights[i] = quantized_weights[i].astype('int8')
			layer_shift.append(shift)
		for i in range(len(test_label)):
			tensor = np.array([test_data[i].reshape((-1))], dtype='float32')
			tensor *= 128
			
			#forward
			for layer in range(n_layer):
				tensor = np.dot(tensor.astype('int32'), quantized_weights[layer].astype('int32'))
				if layer==0:
					tensor //= 128
				tensor //= layer_shift[layer]
				tensor = np.clip(tensor, 0, 127)
			answer = np.argmax(tensor)
			if int(answer) == int(test_label[i]):
				correct += 1
			else:
				error += 1
			tensor = []
		print("\tQuantized Model Accuracy: %0.2f %%" % (correct/(error+correct)*100))
		
		#QuantizedModel Save
		modelfile = open("model_%d_%0.2f.txt" % (iter+1,(correct/(error+correct)*100)), 'w')
		for layer in range(n_layer):
			modelfile.write("%d %d\n" % (model[layer][0], model[layer][1]))
			if layer==0:
				modelfile.write("-1 ")
			else:
				modelfile.write("1 ")
			modelfile.write("%d\n" % layer_shift[layer])
			for e in quantized_weights[layer].reshape((-1)):
				modelfile.write("%d " % e)
			modelfile.write("\n")
		modelfile.write("%d\n" % n_layer)
		modelfile.close()
		
	
elif option == "modeldown":
	if len(sys.argv) < 4:
		print("need model file")
		exit()
	model_file = open(sys.argv[3])
	
	i = 0
	
	N = 0
	layer_size = []
	layer_raw_shift = []
	weights = []
	
	print("Read Model file ...")
	
	# Read Weight File
	while True:
		s = model_file.readline()
		if not s:
			break
		s = s.replace("\n", "")
		s = s.split(' ')
		if i%3==2:
			s = s[:-1]
		if i%3==0:
			if(len(s)==1):
				N = int(s[0])
			else:
				layer_size.append((int(s[0]), int(s[1])))
		elif i%3==1:
			layer_raw_shift.append((int(s[0]), int(s[1])))
		else:
			weights.append([])
			for w in s:
				weights[-1].append(int(w))
		i = i+1
	layer_raw_shift.append((1, 0))
	
	# Compute Shift
	layer_shift = []
	
	for i in range(0, N):
		shift = layer_raw_shift[i][1] / layer_raw_shift[i+1][0]
		if layer_raw_shift[i][0]==-1:
			shift *= 128
		layer_shift.append(int(math.log(shift,2)))
	
	
	print("Construct Model Array ...")
	# Construct Model ByteArray
	modelArr = []
	modelArr.append(0xFF)
	modelArr.append(0x01)
	modelArr.append(N & 0xFF)
	for i in range(0, N):
		S1 = layer_size[i][0]
		S2 = layer_size[i][1]
		shift = layer_shift[i]
		modelArr.append( (S1>>8) & 0xFF)
		modelArr.append( S1 & 0xFF)
		modelArr.append( (S2>>8) & 0xFF)
		modelArr.append( S2 & 0xFF)
		modelArr.append( i & 0xFF)
		modelArr.append( shift & 0xFF)
	modelArr.append(0xFF)
	modelByteArr = bytes(modelArr)
	
	# Construct Weight ByteArray
	weightArr = []
	weightArr.append(0xFF)
	weightArr.append(0x02)
	weightArr.append(N & 0xFF)
	for i in range(0, N):
		S1 = layer_size[i][0]
		S2 = layer_size[i][1]
		shift = layer_shift[i]
		weightArr.append( (S1>>8) & 0xFF)
		weightArr.append( S1 & 0xFF)
		weightArr.append( (S2>>8) & 0xFF)
		weightArr.append( S2 & 0xFF)
		for w in weights[i]:
			weightArr.append(w & 0xFF)
	weightArr.append(0xFF)
	weightByteArr = bytes(weightArr)
	
	#Transmit Model
	print("Trasmmit Data ...")
	ser = serial.Serial(serial_name, 9600, stopbits=serial.STOPBITS_TWO)
	
	ser.write(modelByteArr)
	ser.write(weightByteArr)
	ser.close()
	
	print("Finish")

elif option == "inference":

	if len(sys.argv) < 4:
		print("need model file")
		exit()
	model_file = open(sys.argv[3])
	
	print("Read Model File ...")
	i = 0
	
	N = 0
	layer_size = []
	layer_raw_shift = []
	weights = []
	
	# Read Weight File
	while True:
		s = model_file.readline()
		if not s:
			break
		s = s.replace("\n", "")
		s = s.split(' ')
		if i%3==2:
			s = s[:-1]
		if i%3==0:
			if(len(s)==1):
				N = int(s[0])
			else:
				layer_size.append((int(s[0]), int(s[1])))
		elif i%3==1:
			layer_raw_shift.append((int(s[0]), int(s[1])))
		else:
			weights.append([])
			for w in s:
				weights[-1].append(int(w))
		i = i+1
	
	layer_raw_shift.append((1, 0))
	
	
	# Compute Shift
	layer_shift = []
	
	for i in range(0, N):
		shift = layer_raw_shift[i][1] / layer_raw_shift[i+1][0]
		if layer_raw_shift[i][0]==-1:
			shift *= 128
		layer_shift.append(int(math.log(shift,2)))
	
	#Draw Image
	drawing = False
	
	def onMouse(event, x, y, flags, param):
	    global drawing
	    if event == cv2.EVENT_LBUTTONDOWN:
	        drawing = True
	    if event == cv2.EVENT_LBUTTONUP:
	        drawing = False
	    if event == cv2.EVENT_MOUSEMOVE:
	        if drawing == True:
	            cv2.circle(param, (x, y), 18, (255, 255, 255), -1)
	
	def mouseBrush():
	    img = np.zeros((512, 512, 1), np.uint8)
	    cv2.namedWindow("making Figure")
	    cv2.setMouseCallback("making Figure", onMouse, param=img)
	
	    while True:
	        cv2.imshow("making Figure", img)
	        k = cv2.waitKey(1) & 0xFF
	
	        if k == 27:
	            break
	
	    cv2.destroyAllWindows()
	    return img
		
	def salt_and_pepper(image, p):
	    output = np.zeros(image.shape,np.uint8)
	    thres = 1 - p
	    for i in range(image.shape[0]):
	        for j in range(image.shape[1]):
	            rdn = random.random()
	            if rdn < p:
	                output[i][j] = 0
	            elif rdn > thres:
	                output[i][j] = 255
	            else:
	                output[i][j] = image[i][j]
	    return output
	
	test_img = mouseBrush()
	test_img = salt_and_pepper(test_img, 0.01)
	
	test_img_orig = test_img.copy()
	test_img = cv2.resize(test_img, dsize=(28, 28), interpolation=cv2.INTER_LINEAR)
	test_img = np.reshape(test_img, (1,28,28))
	
	test_img = test_img.astype('int32')
	test_img = test_img - 128
	test_img = test_img.astype('int8')
	test_img = test_img.flatten()
	
	
	# Construct Image ByteArray
	imgArr = []
	imgArr.append(0xFF)
	imgArr.append(0x03)
		
	if len(test_img) != 784:
		print("input image size err")
	for data in test_img:
		imgArr.append(data & 0xFF)
	imgArr.append(0xFF)
		
	imgByteArr = bytes(imgArr)
	
	input = test_img.copy()
	for i in range(0, N):
		weight = np.array(weights[i])
		weight = np.reshape(weight, (layer_size[i][0], layer_size[i][1]))
		output = np.dot(input, weight)
		output = np.clip(output, 0, np.max(output))
		output = np.right_shift(output, layer_shift[i])
		output = np.clip(output, -128, 127)
		input = output.copy()
	print("Expected Result")
	print(input)
	print("Predict: %d" % np.argmax(input))
	
	
	# Transmit image
	print("Trasmmit Data ...")
	ser = serial.Serial(serial_name, 9600, stopbits=serial.STOPBITS_TWO)
	ser.write(imgByteArr)
	ser.close()
	
	cv2.imshow('', test_img_orig);
	cv2.waitKey(0) # waits until a key is pressed
	cv2.destroyAllWindows() # destroys the window showing image
	
	print("Finish")

else:
	print("option error")
	exit()