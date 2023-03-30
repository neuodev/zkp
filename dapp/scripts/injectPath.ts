import fs from 'node:fs';

function main(indexHtmlPath: string, baseUrl: string) {
    const html = fs.readFileSync(indexHtmlPath).toString();
    const fileToUrl = (file: string, withQuotes = true) => {
        const wrapper = withQuotes ? '"' : '';
        return [wrapper, baseUrl, `/${file}`, wrapper].join('');
    };

    const filesToReplace = ['bundle.js'];

    let updatedHtml = filesToReplace.reduce((acc, curr) => {
        return acc.replace(`"${curr}"`, fileToUrl(curr));
    }, html);

    // map `%PUBLIC_URL%/logo.png` -> `<IPFS_LINK>/logo.png`
    updatedHtml = updatedHtml.replace(
        '"%PUBLIC_URL%/logo.png"',
        fileToUrl('logo.png'),
    );

    // map `/manifest.<RANDOM_HASH>` -> `<IPFS_LINK>/manifest.<HASH>`
    updatedHtml = updatedHtml.replace(
        '/manifest.',
        fileToUrl('manifest.', false),
    );

    updatedHtml = updatedHtml.replace(
        '"logo.png"',
        fileToUrl('logo.png', true),
    );

    fs.writeFileSync(indexHtmlPath, updatedHtml);
}

const indexHtmlPath = 'build/index.html';
const baseUrl = 'https://neuodev.github.io/zkp';
main(indexHtmlPath, baseUrl);
