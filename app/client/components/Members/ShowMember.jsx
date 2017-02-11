import React from 'react'
import { ClickableIcon } from '../Common/ClickableIcon'
import css from '../Layout/Dashboard/dashboard.scss'

export const ShowMember = ({ member, onDelete }) => (
  <div className={ css.member }>
    {member.email}
    {member.admin && <span> (admin) </span>}
    <ClickableIcon iconName='trash' clickHandler={ onDelete } classes='small right' />
  </div>
)

