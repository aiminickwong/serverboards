import nodeExternals from 'webpack-node-externals';
var path = require('path')

export default {
  target: 'node',
  externals: [nodeExternals()],
  module: {
      rules: [
          //{ test: /\.jsx$/, loaders: ['react-hot', 'babel'], exclude: /node_modules/ },
          {
            test: /\.js$/,
            exclude: /node_modules/,
            use: ["react-hot-loader", "babel-loader"]
          },
          { test: /\.css$/, use: ["style-loader","css"] },
          {
            test: /\.sass$/,
            use: [{
              loader: "style-loader"
            }, {
              loader: "css-loader"
            }, {
              loader: "sass-loader",
              options : {
                includePaths: ["./"]
              }
            }]
          },
          { test: /\.(jpe?g|png|gif|svg)$/i,
            loaders: [
              'file-loader',
              {
                loader: 'image-webpack-loader',
                query: {
                  mozjpeg: {
                    progressive: true,
                  },
                  gifslice: {
                    interlaced: false,
                  },
                  optipng: {
                    optimizationLevel: 7,
                  },
                  pngquant: {
                    quality: '65-90',
                    speed: 4
                  }
                }
              }
            ]
          }
      ]
  },
  devtool: "cheap-module-source-map",
  resolve: {
    alias:{
      app : path.resolve("./app/js"),
      sass : path.resolve("./app/sass"),
      lang : path.resolve("./lang")
    }
  },
};
