
class AddOrderForm extends HTMLElement {
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
        if (res.orderCompleted) {
          var parsedHtml = new DOMParser().parseFromString(res.orderCompleted, 'text/html');
          const sectionElement = document.getElementById('checkout');
    
          sectionElement.innerHTML = parsedHtml.getElementById('orderCompleted').innerHTML;
        }

        // this.renderContent(res)
        Snackbar.show({
          text: 'Your order was submited successfully!',
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

if (!customElements.get('add-order-form')) {
  customElements.define('add-order-form', AddOrderForm)
}
