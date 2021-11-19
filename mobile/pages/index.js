import { config } from "../app.config";
export { make as default } from "../src/App.bs"

export const getStaticProps = () => ({ props: { config } });
