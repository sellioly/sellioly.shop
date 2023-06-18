// ------------------------------------- global ----------------------------------
function initializeCookie() {
    var cookies = document.cookie.split("; ");
    let exist = false;
    for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i].split("=");
        if (cookie[0] === "cart_id") {
            exist = true;
            return;
        }
    }

    if (!exist) {
        var expirationDate = new Date();
        expirationDate.setDate(expirationDate.getDate() + 365);
        let cart_id = generateRandomString(24);
        var cookieString = `cart_id=${cart_id}; expires=${expirationDate.toUTCString()}; path=/`;
        document.cookie = cookieString;
    }

}
initializeCookie();

function generateRandomString(length) {
    var result = [];
    var characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    var charactersLength = characters.length;
    var bytes = new Uint8Array(length);
    window.crypto.getRandomValues(bytes);
    for (var i = 0; i < length; i++) {
        result.push(characters[bytes[i] % charactersLength]);
    }
    return result.join('');
}

function fetchConfig(type = 'json') {
    return {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json', Accept: `application/${type}` },
    };
}

// ------------------------------- global | end ----------------------------------
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------
// ----------------------------------- cart --------------------------------------

class Cart extends HTMLElement {
    constructor() {
        super();
    }

    getSectionsToRender() {
        return ['cart-notification'];
    }

    renderContent(sections) {
        this.getSectionsToRender().forEach(section_id => {
            var parsedHtml = new DOMParser().parseFromString(sections[section_id], 'text/html');
            const sectionElement = document.getElementById(section_id);

            sectionElement.innerHTML = parsedHtml.getElementById(section_id).innerHTML;
        });
    }
}


// --------------------- variant option radio ----------------------
class VariantOptionsRadio extends HTMLElement {
    constructor() {
        super();
    }
}
customElements.define('variant-options-radio', VariantOptionsRadio);

// --------------------- variant option select ----------------------
class VariantOptionsSelect extends HTMLElement {
    constructor() {
        super();
    }
}
customElements.define('variant-options-select', VariantOptionsSelect);

// --------------------- add to cart form ----------------------
class AddToCartForm extends Cart {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------
        
        this.form.addEventListener('submit', this.onSubmitHandler.bind(this));

        // register variant inputs with type radio 
        this.variantOptions = this.querySelectorAll('variant-options-radio');
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input[type=radio]');
            this.inputs.forEach((input) => {
                input.addEventListener("change", this.handleVariantOptionRadioChange.bind(this));
            })
        });

        // register variant inputs with type select 
        this.variantOptions = this.querySelectorAll('variant-options-select');
        this.variantOptions.forEach(selectInputs => {
            this.selectInput = selectInputs.querySelector('select');
            this.selectInput.addEventListener("change", this.handleVariantOptionSelectChange.bind(this));
        });
    }

    handleVariantOptionRadioChange() {
        let options = {}
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input');
            this.inputs.forEach((input) => {
                if (input.checked) {
                    options[input.name] = input.value;
                }
            })
        })
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionSelectChange() {
        let options = {}
        this.variantOptions.forEach(selectInputs => {
            let selectInput = selectInputs.querySelector('select');
            options[selectInput.name] = selectInput.value;
        });
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionChange(options) {

        const option_length = Object.keys(options).length;
        let i = 0;
        for (i = 0; i < product.variants.length; i++) {
            const productVariant = product.variants[i];

            if (option_length == 3) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value
                    && options[productVariant.option.option3?.name] === productVariant.option.option3?.value) {
                    break;
                }
            }
            else if (option_length == 2) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value) {
                    break;
                }
            }
            else if (option_length == 1) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value) {
                    break;
                }
            }
        }
        if (i < product.variants.length) {
            const variant = product.variants[i];

            this.querySelector('#variant-id').value = variant.id;
            this.querySelector('#product-price').innerHTML = variant.price;
        }
        else {
            this.querySelector('#product-price').innerHTML = "UNAVAILABLE";
        }
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        let buttonContent = this.querySelector('button[type="submit"]').innerHTML;

        this.querySelector('button[type="submit"]').innerHTML = 'loading ...';
        this.querySelector('button[type="submit"]').disabled = true;

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        formData.append('sections', this.getSectionsToRender());

        config.body = formData;

        fetch(`${routes.add_to_cart_url}`, config)
            .then((res) => res.json())
            .then((res) => {
                console.log(res);

                this.querySelector('button[type="submit"]').innerHTML = buttonContent;
                this.querySelector('button[type="submit"]').disabled = false;

                this.renderContent(res.sections)

            })
            .catch((e) => {
                console.error(e);
            })
    }
};

if (!customElements.get('add-to-cart-form')) {
    customElements.define('add-to-cart-form', AddToCartForm)
}


// ---------------- remove from cart form | start -------------------
class RemoveFromCartForm extends Cart {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------

        this.form.addEventListener('submit', this.onSubmitHandler.bind(this));
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        formData.append('sections', this.getSectionsToRender());

        config.body = formData;

        fetch(`${routes.remove_from_cart_url}`, config)
            .then((res) => res.json())
            .then((res) => {
                this.renderContent(res.sections);

                // 
                let variant_id = formData.get('variant_id');
                document.querySelector(`#cart-item-${variant_id}`).remove();

                document.querySelector('[data-id="total-price"]').innerHTML = res.cart.subtotal;
                document.querySelector('[data-id="subtotal-price"]').innerHTML = res.cart.subtotal;
            })
            .catch((e) => {
                console.error(e);
            })
    }
};

if (!customElements.get('remove-from-cart-form')) {
    customElements.define('remove-from-cart-form', RemoveFromCartForm)
}


// ---------------- update cart quantity form | start -------------------

class UpdateCartQuantityForm extends Cart {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------

        this.form.querySelector('input[name="quantity"]').addEventListener('change', this.onSubmitHandler.bind(this));
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        formData.append('sections', this.getSectionsToRender());

        config.body = formData;

        fetch(`${routes.update_cart_quantity_url}`, config)
            .then((res) => res.json())
            .then((res) => {
                this.renderContent(res.sections);

                // update cart page manually
                const variant_id = formData.get('variant_id')
                const cartItemElement = document.querySelector(`#cart-item-${variant_id}`);

                const itemData = res.cart.items.find(item => item.variant_id == variant_id);
                cartItemElement.querySelector('[data-id="total-product-price"]').innerHTML = itemData.price * itemData.quantity;

                document.querySelector('[data-id="total-price"]').innerHTML = res.cart.subtotal;
                document.querySelector('[data-id="subtotal-price"]').innerHTML = res.cart.subtotal;
            })
            .catch((e) => {
                console.error(e);
            })
    }
};

if (!customElements.get('update-cart-quantity-form')) {
    customElements.define('update-cart-quantity-form', UpdateCartQuantityForm)
}

// --------------------- buy now form | start ----------------------
class BuyNowForm extends HTMLElement {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------
        
        this.form.addEventListener('submit', this.onSubmitHandler.bind(this));

        // register variant inputs with type radio 
        this.variantOptions = this.querySelectorAll('variant-options-radio');
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input[type=radio]');
            this.inputs.forEach((input) => {
                input.addEventListener("change", this.handleVariantOptionRadioChange.bind(this));
            })
        });

        // register variant inputs with type select 
        this.variantOptions = this.querySelectorAll('variant-options-select');
        this.variantOptions.forEach(selectInputs => {
            this.selectInput = selectInputs.querySelector('select');
            this.selectInput.addEventListener("change", this.handleVariantOptionSelectChange.bind(this));
        });
    }

    handleVariantOptionRadioChange() {
        let options = {}
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input');
            this.inputs.forEach((input) => {
                if (input.checked) {
                    options[input.name] = input.value;
                }
            })
        })
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionSelectChange() {
        let options = {}
        this.variantOptions.forEach(selectInputs => {
            let selectInput = selectInputs.querySelector('select');
            options[selectInput.name] = selectInput.value;
        });
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionChange(options) {

        const option_length = Object.keys(options).length;
        let i = 0;
        for (i = 0; i < product.variants.length; i++) {
            const productVariant = product.variants[i];

            if (option_length == 3) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value
                    && options[productVariant.option.option3?.name] === productVariant.option.option3?.value) {
                    break;
                }
            }
            else if (option_length == 2) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value) {
                    break;
                }
            }
            else if (option_length == 1) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value) {
                    break;
                }
            }
        }
        if (i < product.variants.length) {
            const variant = product.variants[i];

            this.querySelector('#variant-id').value = variant.id;
            this.querySelector('#product-price').innerHTML = variant.price;
        }
        else {
            this.querySelector('#product-price').innerHTML = "UNAVAILABLE";
        }
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        this.querySelector('button[type="submit"]').innerHTML = 'loading ...';
        this.querySelector('button[type="submit"]').disabled = true;

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        config.body = formData;

        fetch(`${routes.buy_now_url}`, config)
            .then((res) => res.json())
            .then((res) => {
                console.log(res);

                window.location.href = "/checkout"
            })
            .catch((e) => {
                console.error(e);

            })
    }
};

if (!customElements.get('buy-now-form')) {
    customElements.define('buy-now-form', BuyNowForm)
}



// ----------------------------------- checkout ----------------------------------
class AddOrderForm extends HTMLElement {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------
        
        this.form.addEventListener('submit', this.onSubmitHandler.bind(this));
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        // formData.append('sections', this.getSectionsToRender());

        config.body = formData;

        fetch(`${routes.add_order_url}`, config)
            .then((res) => {
                if (res.status >= 400) {
                    throw new Error();
                }
                return res.json();
            })
            .then((res) => {
                console.log(res);

                // render order completed section
                if (res['order-completed']) {
                    var parsedHtml = new DOMParser().parseFromString(res['order-completed'], 'text/html');
                    const sectionElement = document.getElementById('checkout');

                    sectionElement.innerHTML = parsedHtml.getElementById('order-completed').innerHTML;
                }

                // window.location.href = "/"
            })
            .catch((e) => {
                console.error(e);
            })
    }
};

if (!customElements.get('add-order-form')) {
    customElements.define('add-order-form', AddOrderForm)
}



// --------------------- add to cart form ----------------------
class OrderNowForm extends Cart {
    constructor() {
        super();

        // create form element
        this.form = document.createElement('form');
        this.form.innerHTML = this.innerHTML;
        this.innerHTML = "";
        this.appendChild(this.form);
        // -------------------
        
        this.form.addEventListener('submit', this.onSubmitHandler.bind(this));

        // register variant inputs with type radio 
        this.variantOptions = this.querySelectorAll('variant-options-radio');
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input[type=radio]');
            this.inputs.forEach((input) => {
                input.addEventListener("change", this.handleVariantOptionRadioChange.bind(this));
            })
        });

        // register variant inputs with type select 
        this.variantOptions = this.querySelectorAll('variant-options-select');
        this.variantOptions.forEach(selectInputs => {
            this.selectInput = selectInputs.querySelector('select');
            this.selectInput.addEventListener("change", this.handleVariantOptionSelectChange.bind(this));
        });
    }

    handleVariantOptionRadioChange() {
        let options = {}
        this.variantOptions.forEach(optionInputs => {
            this.inputs = optionInputs.querySelectorAll('input');
            this.inputs.forEach((input) => {
                if (input.checked) {
                    options[input.name] = input.value;
                }
            })
        })
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionSelectChange() {
        let options = {}
        this.variantOptions.forEach(selectInputs => {
            let selectInput = selectInputs.querySelector('select');
            options[selectInput.name] = selectInput.value;
        });
        console.log(options);

        this.handleVariantOptionChange(options);
    }

    handleVariantOptionChange(options) {

        const option_length = Object.keys(options).length;
        let i = 0;
        for (i = 0; i < product.variants.length; i++) {
            const productVariant = product.variants[i];

            if (option_length == 3) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value
                    && options[productVariant.option.option3?.name] === productVariant.option.option3?.value) {
                    break;
                }
            }
            else if (option_length == 2) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value &&
                    options[productVariant.option.option2?.name] === productVariant.option.option2?.value) {
                    break;
                }
            }
            else if (option_length == 1) {
                if (options[productVariant.option.option1?.name] === productVariant.option.option1?.value) {
                    break;
                }
            }
        }
        if (i < product.variants.length) {
            const variant = product.variants[i];

            this.querySelector('#variant-id').value = variant.id;
            this.querySelector('#product-price').innerHTML = variant.price;
        }
        else {
            this.querySelector('#product-price').innerHTML = "UNAVAILABLE";
        }
    }

    onSubmitHandler(evt) {
        evt.preventDefault();

        let buttonContent = this.querySelector('button[type="submit"]').innerHTML;

        this.querySelector('button[type="submit"]').innerHTML = 'loading ...';
        this.querySelector('button[type="submit"]').disabled = true;

        const config = fetchConfig('javascript');
        config.headers['X-Requested-With'] = 'XMLHttpRequest';
        delete config.headers['Content-Type'];

        const formData = new FormData(this.form);
        formData.append('cart_id', window.config.cart_id);
        // formData.append('sections', this.getSectionsToRender());

        config.body = formData;

        fetch(`${routes.order_now_url}`, config)
            .then((res) => res.json())
            .then((res) => {
                console.log(res);

                this.querySelector('button[type="submit"]').innerHTML = buttonContent;
                this.querySelector('button[type="submit"]').disabled = false;

                this.querySelector('#order-now-form').innerHTML = `
                    <div class=" text-center" style="padding-top: 3rem;border-top: 0.1rem solid #ebebeb;">
                        <span class="icon-box-icon">
                            <i class="icon-star-o"></i>
                        </span>
                        <h2 class="title text-center">Order completed!</h2>
                        <h3 class="icon-box-title">Order id: #${res.order_id}</h3>
                    </div>
                `

                // this.renderContent(res.sections);

            })
            .catch((e) => {
                console.error(e);
            })
    }
};

if (!customElements.get('order-now-form')) {
    customElements.define('order-now-form', OrderNowForm)
}