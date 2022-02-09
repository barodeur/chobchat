import React from 'react';
import { getInitialProps } from '@expo/next-adapter/document';
import Document, { Html, Head, Main, NextScript } from "next/document"

export default class extends Document {
  static getInitialProps = getInitialProps

  render() {
    return (
      <Html>
        <Head>
          <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        </Head>
        <body style={{ height: "100%", width: "100%" }}>
          <Main />
          <NextScript />
        </body>
      </Html>
    );
  }
}
