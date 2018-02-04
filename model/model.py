import tensorflow as tf

kline = tf.placeholder(dtype=tf.float32, shape=[None, 132, 10])
depth = tf.placeholder(dtype=tf.float32, shape=[None, 5, 4])
label = tf.placeholder(dtype=tf.float32, shape=[None, 5, 5])

conv1 = tf.layers.conv1d(kline, filters=10, kernel_size=5, activation=tf.nn.leaky_relu, padding='valid')
pool1 = tf.layers.max_pooling1d(conv1, 2, 2)
conv2 = tf.layers.conv1d(pool1, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool2 = tf.layers.max_pooling1d(conv2, 2, 2)
conv3 = tf.layers.conv1d(pool2, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool3 = tf.layers.max_pooling1d(conv3, 2, 2)
conv4 = tf.layers.conv1d(pool3, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool4 = tf.layers.max_pooling1d(conv4, 2, 2)

kline_feature = tf.layers.dense(pool4, 10, activation=tf.nn.leaky_relu)
depth_feature = tf.layers.dense(depth, 10, activation=tf.nn.leaky_relu)

cat = tf.concat([kline_feature, depth_feature], 1)
fc1 = tf.layers.dense(cat, 10, activation=tf.nn.leaky_relu)
fc2 = tf.layers.dense(fc1, 25)
out = tf.nn.log_softmax(tf.reshape(fc2, [-1, 5, 5]))

loss = tf.reduce_sum(- out * label)
step = tf.train.GradientDescentOptimizer(0.01).minimize(loss)

saver = tf.train.Saver()

sess = tf.Session()

try:
    saver.restore(sess, "/var/HumbleGamble2/model.ckpt")
except:
    sess.run(tf.initializers.global_variables())

def predict(dkline, ddepth):
    return sess.run(out, feed_dict={ kline: dkline, depth: ddepth })

def train(dkline, ddepth, dlabel):
    return [sess.run([loss, step], feed_dict={ kline: dkline, depth: ddepth, label: dlabel })[0] for i in range(5)]

def save():
    return saver.save(sess, "/var/HumbleGamble2/model.ckpt")
