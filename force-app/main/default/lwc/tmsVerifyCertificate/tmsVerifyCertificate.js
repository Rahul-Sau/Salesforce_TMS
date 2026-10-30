import { LightningElement } from 'lwc';
import verify from '@salesforce/apex/TMS_VerifyController.verify';

export default class TmsVerifyCertificate extends LightningElement {
    code = '';
    result;
    searched = false;
    loading = false;

    connectedCallback() {
        const fromUrl = new URLSearchParams(window.location.search).get('code');
        if (fromUrl) {
            this.code = fromUrl.toUpperCase();
            this.check();
        }
    }
    handleChange(event) { this.code = event.target.value; }
    handleClick() { this.check(); }

    async check() {
        this.loading = true;
        this.searched = false;
        try {
            this.result = await verify({ code: this.code });
        } catch (e) {
            this.result = { found: false };
        }
        this.loading = false;
        this.searched = true;
    }
    get found() { return this.result && this.result.found; }
    get notFound() { return this.searched && !this.found; }
}