import tensorflow as tf

kline = tf.placeholder(dtype=tf.float32, shape=[None, 132, 10])
depth = tf.placeholder(dtype=tf.float32, shape=[None, 5, 4])
state = tf.placeholder(dtype=tf.float32, shape=[None, 4])
label = tf.placeholder(dtype=tf.float32, shape=[None, 5])

conv1 = tf.layers.conv1d(kline, filters=10, kernel_size=5, activation=tf.nn.leaky_relu, padding='valid')
pool1 = tf.layers.max_pooling1d(conv1, 2, 2)
conv2 = tf.layers.conv1d(pool1, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool2 = tf.layers.max_pooling1d(conv2, 2, 2)
conv3 = tf.layers.conv1d(pool2, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool3 = tf.layers.max_pooling1d(conv3, 2, 2)
conv4 = tf.layers.conv1d(pool3, filters=10, kernel_size=5, activation=tf.nn.leaky_relu)
pool4 = tf.layers.max_pooling1d(conv4, 2, 2)

kline_feature = tf.layers.dense(pool4, 10)
depth_feature = tf.layers.dense(depth, 10)

cat = tf.concat([kline_feature, depth_feature, state], 1)
fc1 = tf.layers.dense(cat, 10)
fc2 = tf.layers.dense(fc1, 5)
out = tf.nn.log_softmax(fc2)

loss = tf.reduce_sum(- out * label)
step = tf.train.GradientDescentOptimizer(0.01).minimize(loss)

saver = tf.train.Saver()

sess = tf.Session()

try:
    saver.restore(sess, "/var/HumbleGamble2/model.ckpt")
except e:
    print(e)
    sess.run(tf.initializers.global_variables())

def predict_all(dkline, ddepth):
    def rep(x, i):
        return x[i:i+1].repeat(5, axis=0)
    kf, df = sess.run([kline_feature, depth_feature], feed_dict={ kline: dkline, depth: ddepth })
    states = [[0,0,0,0], [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]]
    return [sess.run(out, feed_dict={ kline_feature: rep(kf, i), depth_feature: rep(df, i), state: states }) for i in range(dkline.shape[0])]

def predict(dkline, ddepth, dstate):
    return sess.run(out, feed_dict={ kline: dkline, depth: ddepth, state: dstate })

def train(dkline, ddepth, dstate, dlabel):
    for i in range(5):
        x, _ = sess.run([loss, step], feed_dict={ kline: dkline, depth: ddepth, state: dstate, label: dlabel })
    return x

def save():
    saver.save(sess, "/var/HumbleGamble2/model.ckpt")



