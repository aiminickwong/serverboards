const {rpc, React} = Serverboards
const plugin_id="[plugin-id]"

function View(props){
  return (
    <pre>
      {JSON.stringify(props, undefined, 2)}
    </pre>
  )
}

function main(el, config){
  Serverboards.ReactDOM.render(<View/>, el)

  return function(){
    Serverboards.ReactDOM.unmountComponentAtNode(el)
  }
}

Serverboards.add_[component-type](`${plugin_id}/[component-type]`, main)
