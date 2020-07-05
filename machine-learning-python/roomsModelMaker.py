#!/usr/bin/env python
"""
This python script is used to train a ML model for the "Rooms" iOS app.
Author: st0nedB
GitHub: https://github.com/st0nedB/
"""

import logging
import argparse
import numpy as np
import json
import os
import coremltools
import http.server, socketserver
# for preprocessing the data
from sklearn.preprocessing import OneHotEncoder
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelBinarizer
from sklearn.metrics import plot_confusion_matrix, confusion_matrix, ConfusionMatrixDisplay
import matplotlib.pyplot as plt
# for learning
from keras.models import Sequential
from keras.layers import Dense, Activation
import keras.optimizers as optimizers
import keras.losses as losses
from keras_tqdm import TQDMCallback

def get_options():
    description = ''
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument('--num-beacon', help='The number of beacons used.', required=True, type=int)
    parser.add_argument('--num-epochs', help='The number of epochs to train for. Default = 300', type=int, default=300)
    parser.add_argument('--batch-size', help='The batch size to use for training. Default = 0.', type=int, default=0)
    parser.add_argument('--activation-function', help='The activation function to use. Default = "relu". Must be a valid keras activation function name.', type=str, default="relu")
    parser.add_argument('--http', help="Enables a simple http server to serve the file to the app", nargs='?', const=True, default=False)
    parser.add_argument('--port', help="The port for the http server to run on.", nargs='?', type=int, const=8000, default=8000)

    return parser.parse_args()


def set_logging(level=logging.INFO):
    logger = logging.getLogger()
    logger.setLevel(level)
    ch = logging.StreamHandler()
    logger.addHandler(ch)
    return logger

def loadData(nbeacon) -> (list, list, int):
    files = [file for file in os.listdir(".") if file.endswith(".json")]  # find all json files in the directory
    jsondata = []
    rooms = []
    nsamples = 0
    # read data and append to list, not very clean, but the amount of data is not very large
    for file in files:
        with open(file, "r") as jsonfile:
            try:
                fio = np.array(json.load(jsonfile))
                nsamples += fio.shape[0]
                rooms.append(str(file).split(".")[0])
                jsondata.append(fio)
            except:
                logging.warning("Skipping {:s} does not contain valid data.".format(str(file)))
    
    return jsondata, rooms, nsamples

def makeLabelBinarizer(rooms) -> LabelBinarizer:
    lb = LabelBinarizer()
    
    return lb.fit(rooms)

def parseData(jsondata, rooms, nsamples, lb) -> (np.array, np.array):
    # preallocate memory
    data = np.empty((nsamples,nbeacon))
    ohlabels = np.empty((nsamples,len(rooms)))
    
    ii = 0  # index to go through the data
    nn = dict.fromkeys(rooms)  # list with data amounts
    
    # iterate through data
    for dd,rr in zip(jsondata,rooms):
        N = np.shape(dd)[0]
        nn[rr] = N
        data[ii:ii+N] = dd
        ohlabels[ii:ii+N] = np.repeat(lb.transform([rr]), repeats=N, axis=0)
        ii += N
        
    data[data == -100] = 1  # this is due to a bug in AdditionalClasses.swift (fixed by commit 8555556ddc380be788b8e2b6f93a79a290acc7cc), leaving it here doesn't hurt and provides backwards compatibility.
        
    logging.info("Summary of loaded data:\n" + str(nn))
    
    return data, ohlabels

def makeModel(inputshape, nlabels, actfunc):
    model = Sequential()
    model.add(Dense(32, input_shape=(inputshape,)))
    model.add(Dense(32, activation=actfunc))
    model.add(Dense(16, activation=actfunc))
    model.add(Dense(16, activation=actfunc))
    model.add(Dense(units=nlabels, activation="softmax"))
    model.compile(
        optimizer=optimizers.Adam(),
        loss="categorical_crossentropy",
        metrics=['categorical_accuracy']
    )
    model.summary()
    
    return model

def trainModel(model, X_train, Y_train, X_test, Y_test, nepochs, nbatch):
    if nbatch == 0:
        nbatch = X_train.shape[0]
        
    model.fit(X_train, Y_train, epochs=nepochs, batch_size=nbatch, verbose=0, callbacks=[TQDMCallback()])
    score = model.evaluate(X_test, Y_test)
    
    return model, score

def plotConfusionMatrix(ytest, ypred, labels):
    cm = confusion_matrix(ytest.argmax(axis=1), ypred.argmax(axis=1), normalize=None, labels=np.arange(5))
    confMat = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=labels)
    cm = confMat.plot()
    input("Press any key to continue....")

def convertCoreML(keras_model, labelbinarizer):
    # modelName for coreML model
    modelName = "rooms_coreml"
    cleaned_path = "."

    class_labels = labelbinarizer.classes_.tolist()

    # load the trained convolutional neural network

    model = coremltools.converters.keras.convert(
                keras_model,
                input_names=["dense_1_input_output"],
                class_labels=class_labels,
                )

    spec = model.get_spec()
    model.author = "Rooms - https://github.com/st0nedB/rooms"
    model.license = "MIT"
    model.short_description = "This model can be used to predict in which room a device resides based on BLE beacon measurements."
    model.versionString =  "Version 0.1"
    model.save(cleaned_path + "/" + modelName +  ".mlmodel")
    
def serveHTTPFile(port):
    handler = http.server.SimpleHTTPRequestHandler
    
    with socketserver.TCPServer(("", port), handler) as httpd:
        logging.info("Server started at localhost:" + str(port))
        logging.info("Press CRTL+C to stop...")
        httpd.serve_forever()

    
if __name__ == "__main__":
    options = get_options()
    logger = set_logging()
    
    # parse the options
    nbeacon = options.num_beacon
    nepochs = options.num_epochs
    nbatch = options.batch_size
    actfunc = options.activation_function
    servehttp = options.http
    port = options.port

    # load input data from json files
    data, rooms, nsamples = loadData(nbeacon=6)

    # make a label binarizer object
    lbinarizer = makeLabelBinarizer(rooms)

    # parse the data 
    X, Y = parseData(jsondata=data, rooms=rooms, nsamples=nsamples, lb=lbinarizer)

    # split into train-test set
    X_train, X_test, Y_train, Y_test = train_test_split(X, Y, shuffle=True, test_size=0.1)
    
    # setup and train the model 
    mlmodel = makeModel(inputshape=X_train.shape[1], nlabels=len(rooms), actfunc=actfunc)
    mlmodel, score = trainModel(model=mlmodel, X_train=X_train, X_test=X_test, Y_train=Y_train, Y_test=Y_test, nepochs=nepochs, nbatch=nbatch)
    logging.info("Model loss: {:.4f} \t Model accuracy: {:.4f} ".format(*score))
    #plotConfusionMatrix(ytest=Y, ypred=mlmodel.predict(X), labels=rooms) not working correctly right now
    
    # convert trained keras model to CoreML model, saved in rooms_coreml.mlmodel
    convertCoreML(keras_model=mlmodel, labelbinarizer=lbinarizer)
    
    # serve the file on http, if requested by --http argument
    if servehttp: 
        logging.info("Starting http server at port {:d} to serve {:s}".format(port, "rooms_coreml.mlmodel"))
        serveHTTPFile(port=port)