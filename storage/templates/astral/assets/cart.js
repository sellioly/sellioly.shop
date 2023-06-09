class Cart extends HTMLElement {
  constructor() {
    super();
  }

  getSectionsToRender() {
    return ['cart-notification', 'cart-notification-icon-desk'];
  }

  renderContent(sections) {
    this.getSectionsToRender().forEach(section_id => {
      var parsedHtml = new DOMParser().parseFromString(sections[section_id], 'text/html');
      const sectionElement = document.getElementById(section_id);

      sectionElement.innerHTML = parsedHtml.getElementById(section_id).innerHTML;
    });
  }
}


class VariantOption extends HTMLElement {
  constructor() {
    super();
  }
}
customElements.define('variant-options', VariantOption);

// --------------------- add to cart form | start ----------------------
class AddToCartForm extends Cart {
  constructor() {
    super();

    this.form = this.querySelector('form');
    this.form.addEventListener('submit', this.onSubmitHandler.bind(this));

    // register variant inputs with type radio 
    this.variantOptions = this.querySelectorAll('variant-options');
    this.variantOptions.forEach(optionInputs => {
      this.inputs = optionInputs.querySelectorAll('input[type=radio]');
      this.inputs.forEach((input) => {
        input.addEventListener("change", this.handleVariantOptionChange.bind(this));
      })
    });
  }

  handleVariantOptionChange(event) {
    let options = {}
    this.variantOptions.forEach(optionInputs => {
      this.inputs = optionInputs.querySelectorAll('input');
      this.inputs.forEach((input) => {
        if(input.checked) {
          options[input.name] = input.value;
        }
      })
    })
    console.log(options);

    const option_length = Object.keys(options).length;
    let i=0;
    for(i=0; i< product.variants.length; i++){
      const productVariant = product.variants[i];

      if(option_length ==3){
        if(options[productVariant.option.option1?.name] === productVariant.option.option1?.value && 
        options[productVariant.option.option2?.name] === productVariant.option.option2?.value
        && options[productVariant.option.option3?.name] === productVariant.option.option3?.value){
          break;
        }
      }
      else if(option_length == 2){
        if(options[productVariant.option.option1?.name] === productVariant.option.option1?.value && 
        options[productVariant.option.option2?.name] === productVariant.option.option2?.value){
          break;
        }
      }
      else if(option_length == 1){
        if(options[productVariant.option.option1?.name] === productVariant.option.option1?.value){
          break;
        }
      }
    }
    if(i < product.variants.length){
          const variant = product.variants[i];

          this.querySelector('#variant-id').value = variant.id;
          this.querySelector('#product-price').innerHTML = variant.price;
    }
    else{
          this.querySelector('#product-price').innerHTML = "UNAVAILABLE";
    }

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

    fetch(`${routes.add_to_cart_url}`, config)
      .then((res) => res.json())
      .then((res) => {
        console.log(res);

        this.renderContent(res)
        Snackbar.show({
          text: 'Your product was added to cart successfully!',
          pos: 'top-center',
          showAction: false,
          actionText: "Dismiss",
          duration: 3000,
          textColor: '#fff',
          backgroundColor:'#151515'
        }); 
      })
      .catch((e) => {
        console.error(e);

        Snackbar.show({
          text: 'Something when wrong!',
          pos: 'top-center',
          showAction: false,
          actionText: "Dismiss",
          duration: 3000,
          textColor: '#fff',
          backgroundColor:'#151515'
        });
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

    this.form = this.querySelector('form');
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

        this.renderContent(res)
        Snackbar.show({
          text: 'product was removed from the cart!',
          pos: 'top-center',
          showAction: false,
          actionText: "Dismiss",
          duration: 3000,
          textColor: '#fff',
          backgroundColor:'#151515'
        }); 
      })
      .catch((e) => {
        console.error(e);

        Snackbar.show({
          text: 'Something when wrong!',
          pos: 'top-center',
          showAction: false,
          actionText: "Dismiss",
          duration: 3000,
          textColor: '#fff',
          backgroundColor:'#151515'
        });
      })
  }
};

if (!customElements.get('remove-from-cart-form')) {
  customElements.define('remove-from-cart-form', RemoveFromCartForm)
}
// ---------------- remove from cart form | end -------------------