import React from 'react'
import i18n from 'app/utils/i18n'

function RuleMenu(props){
  return (
    <div className="right menu">
      <div className="item">
        <a onClick={props.gotoRules} className="ui button basic">{props.cancel_label || i18n("Back to rules")}</a>
      </div>
      <div className="item">
        <a onClick={props.saveRule} className={`ui button teal ${props.saveRule ? "" : "disabled"}`}>{props.save_label || i18n("Save rule")}</a>
      </div>
    </div>
  )
}

export default RuleMenu
